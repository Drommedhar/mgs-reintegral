extends Node

signal changed(state: Dictionary)
signal finished(result: String, error: String)

const CONFIRM_SECONDS = 15
var session_id := PackedByteArray()
var applied: Dictionary = {}
var supported := false
var phase := "idle"
var last_error := ""
var deadline_msec := 0
var storage: Node
var surface: RefCounted
var _candidate: Dictionary = {}
var _previous: Dictionary = {}
var _request_id := 0
var _store_id := 0
var _reference := false

func configure(provider: Node, driver: RefCounted) -> void:
	storage = provider
	surface = driver
	storage.request_finished.connect(_storage_finished)

func snapshot() -> Dictionary:
	return {"applied":applied.duplicate(), "live_apply":supported, "phase":phase,
		"remaining_seconds":maxf(0, (deadline_msec - Time.get_ticks_msec()) / 1000.0) if phase == "preview" else 0.0,
		"error":last_error}

func preview(changes: Dictionary) -> String:
	if not supported or applied.is_empty(): return "Native live display control is unavailable"
	if phase != "idle": return "A display transaction is already pending"
	if changes.is_empty(): return "No display changes supplied"
	_candidate = applied.duplicate()
	_candidate.merge(changes, true)
	_store_id = storage.request("validate", _candidate)
	if _store_id == 0: return storage.last_error
	_previous = applied.duplicate()
	last_error = ""
	_set_phase("validating")
	return ""

func confirm() -> String:
	if phase != "preview": return "No applied display preview to confirm"
	_store_id = storage.request("save", applied)
	if _store_id == 0: return storage.last_error
	_set_phase("saving")
	return ""

func revert() -> String:
	if phase != "preview": return "No applied display preview to revert"
	_set_phase("rollback_queued")
	return ""

func _process(_delta: float) -> void:
	if phase == "preview" and Time.get_ticks_msec() >= deadline_msec:
		last_error = "Display confirmation timed out"
		revert()

func _set_phase(value: String) -> void:
	phase = value
	changed.emit(snapshot())

func _complete(result: String, error: String = "") -> void:
	_candidate = {}
	_previous = {}
	deadline_msec = 0
	last_error = error
	_set_phase("idle")
	finished.emit(result, error)

func _storage_finished(id: int, error: String) -> void:
	if id != _store_id: return
	_store_id = 0
	if phase == "validating":
		if not error.is_empty(): _complete("rejected", error)
		else: _set_phase("queued")
	elif phase == "saving":
		if error.is_empty():
			await _confirm_saved()
		else:
			last_error = error
			_store_id = storage.request("read")
			if _store_id:
				_set_phase("reconciling")
			else:
				last_error += "; saved settings could not be verified: " + storage.last_error
				_set_phase("rollback_queued")
	elif phase == "reconciling":
		if error.is_empty() and storage.snapshot.saved == applied:
			await _confirm_saved()
		else:
			if not error.is_empty(): last_error += "; saved settings could not be verified: " + error
			_set_phase("rollback_queued")

func _confirm_saved() -> void:
	_set_phase("finishing")
	var error: String = await surface.finish(false, applied, _reference)
	if error.is_empty(): _complete("confirmed")
	else:
		last_error = "Settings saved, but display cleanup failed: " + error
		_set_phase("failed")
		finished.emit("failed", last_error)

func _validate_wire(data: PackedByteArray) -> String:
	if data.size() != 48 or data.decode_u32(0) != 1: return "Invalid display state layout"
	if session_id.size() != 16 or data.slice(16,32) != session_id: return "Display session mismatch"
	if data.decode_u32(4) != _request_id: return "Display acknowledgement mismatch"
	for offset in [8,12,40,44]:
		if data.decode_u32(offset) > 1: return "Invalid display flag"
	var width := data.decode_u32(32)
	var height := data.decode_u32(36)
	var wide := data.decode_u32(40) != 0
	if width < 320 or width > 2560 or height < 240 or height > (1792 if wide else 1920): return "Invalid native display extent"
	if wide and (width*3 < height*4 or width*3 > height*12): return "Invalid native display aspect"
	return ""

func _reply(values: Dictionary = {}) -> PackedByteArray:
	if values.is_empty(): return PackedInt32Array([1,0,0,0,0]).to_byte_array()
	_request_id += 1
	var size: Vector2i = preload("res://display_surface.gd").extent(values)
	return PackedInt32Array([1,_request_id,size.x,size.y,int(values["display.widescreen"])]).to_byte_array()

func exchange(data: PackedByteArray) -> Dictionary:
	var error := _validate_wire(data)
	if not error.is_empty(): return {"error":error}
	_reference = data.decode_u32(44) != 0
	supported = data.decode_u32(12) != 0
	var actual := {"display.resolution":"%dx%d"%[data.decode_u32(32),data.decode_u32(36)],
		"display.widescreen":data.decode_u32(40)!=0, "display.fullscreen":surface.fullscreen()}
	if applied.is_empty():
		applied = actual
		changed.emit(snapshot())
	if phase == "queued":
		error = await surface.prepare(_candidate)
		if not error.is_empty(): _complete("rejected", error)
		else:
			_set_phase("native_pending")
			return {"reply":_reply(_candidate)}
	elif phase == "native_pending":
		return await _acknowledge(data.decode_u32(8), actual)
	elif phase == "rollback_pending":
		if data.decode_u32(8) != 0 or not _projection_matches(actual, _previous): return {"error":"Native display restoration failed"}
		error = await surface.finish(true, _previous, _reference)
		if not error.is_empty(): return {"error":error}
		applied = _previous.duplicate()
		_complete("reverted", last_error)
	if phase == "rollback_queued":
		_set_phase("rollback_pending")
		return {"reply":_reply(_previous)}
	return {"reply":_reply()}

static func _projection_matches(actual: Dictionary, expected: Dictionary) -> bool:
	return actual["display.resolution"] == expected["display.resolution"] and actual["display.widescreen"] == expected["display.widescreen"]

func _acknowledge(status: int, actual: Dictionary) -> Dictionary:
	if status != 0:
		if not _projection_matches(actual, _previous): return {"error":"Rejected native display changed projection"}
		var error: String = await surface.discard()
		if not error.is_empty(): return {"error":error}
		_complete("rejected", "Native renderer rejected display settings")
		return {"reply":_reply()}
	if not _projection_matches(actual, _candidate): return {"error":"Native display acknowledgement has the wrong projection"}
	var error: String = await surface.commit(_candidate, _reference)
	if not error.is_empty():
		last_error = error
		_set_phase("rollback_pending")
		return {"reply":_reply(_previous)}
	applied = _candidate.duplicate()
	deadline_msec = Time.get_ticks_msec() + CONFIRM_SECONDS*1000
	_set_phase("preview")
	return {"reply":_reply()}
