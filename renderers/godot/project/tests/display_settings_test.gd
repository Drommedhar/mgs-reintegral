extends SceneTree

class Store extends Node:
	signal request_finished(id: int, error: String)
	var snapshot := {"saved":{}}
	var last_error := ""
	var requests: Array = []
	func request(action: String, values: Dictionary = {}) -> int:
		requests.append([action, values.duplicate()])
		return requests.size()
	func finish(error: String = "") -> void:
		request_finished.emit(requests.size(), error)

class Surface extends RefCounted:
	var full := false
	var failure := ""
	var events: Array = []
	func fullscreen() -> bool: return full
	func prepare(_values: Dictionary) -> String:
		events.append("prepare")
		return failure
	func commit(values: Dictionary, _reference: bool) -> String:
		events.append("commit")
		full = values["display.fullscreen"]
		return failure
	func discard() -> String:
		events.append("discard")
		return ""
	func finish(restore: bool, values: Dictionary, _reference: bool) -> String:
		events.append("restore" if restore else "confirm")
		if restore: full = values["display.fullscreen"]
		return ""

var failures := 0
var display := preload("res://display_settings.gd").new()
var store := Store.new()
var surface := Surface.new()
var serial := 0
var original := {"display.resolution":"640x480","display.widescreen":false,"display.fullscreen":false}
var desired := {"display.resolution":"1280x720","display.widescreen":true,"display.fullscreen":true}

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func packet(values: Dictionary, status := 0) -> PackedByteArray:
	var size := preload("res://display_surface.gd").extent(values)
	return PackedInt32Array([1,serial,status,1,0,0,0,0,size.x,size.y,int(values["display.widescreen"]),0]).to_byte_array()

func exchange(values: Dictionary, status := 0) -> Dictionary:
	var response := await display.exchange(packet(values, status))
	check(not response.has("error"), "Wire rejected: " + str(response))
	if response.has("reply") and response.reply.decode_u32(4): serial = response.reply.decode_u32(4)
	return response

func begin() -> void:
	check(display.preview(desired).is_empty(), "Preview rejected")
	check(store.requests[-1][0] == "validate", "Preview persisted before confirmation")
	store.finish()
	await exchange(original)
	check(display.phase == "native_pending" and display.applied == original, "Preview committed before native ack")
	await exchange(desired)
	check(display.phase == "preview" and display.applied == desired, "Native ack did not commit")

func rollback() -> void:
	await exchange(desired)
	check(display.phase == "rollback_pending", "Rollback request absent")
	await exchange(original)
	check(display.phase == "idle" and display.applied == original and not surface.full, "Rollback did not restore applied state")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	root.add_child(store)
	root.add_child(display)
	display.configure(store, surface)
	display.session_id.resize(16)
	await exchange(original)
	var bad := packet(original)
	bad[16] = 1
	check((await display.exchange(bad)).has("error"), "Wrong session accepted")
	bad = packet(original)
	bad.encode_u32(4, 42)
	check((await display.exchange(bad)).has("error"), "Wrong acknowledgement accepted")
	await begin()
	check(not display.preview(desired).is_empty(), "Overlapping preview accepted")
	check(display.revert().is_empty(), "Revert rejected")
	await rollback()
	await begin()
	display.deadline_msec = 0
	display._process(0)
	await rollback()
	check(store.requests.size() == 2, "Unconfirmed previews wrote settings")
	surface.failure = "allocation refused"
	check(display.preview(desired).is_empty(), "Allocation test could not start")
	store.finish()
	await exchange(original)
	check(display.phase == "idle" and display.applied == original, "Allocation failure changed applied settings")
	surface.failure = ""
	check(display.preview(desired).is_empty(), "Rejection test could not start")
	store.finish()
	await exchange(original)
	await exchange(original, 1)
	check(display.phase == "idle" and surface.events[-1] == "discard", "Rejected native change did not discard buffers")
	check(display.preview(desired).is_empty(), "Window failure test could not start")
	store.finish()
	await exchange(original)
	surface.failure = "window rejected fullscreen"
	await exchange(desired)
	check(display.phase == "rollback_pending", "Window failure did not request native rollback")
	await exchange(original)
	check(display.phase == "idle" and display.applied == original and not surface.full, "Window failure did not restore both layers")
	surface.failure = ""
	await begin()
	check(display.confirm().is_empty(), "Failed persistence test could not confirm")
	store.finish("save disconnected")
	store.finish("read disconnected")
	await rollback()
	check(display.last_error.contains("saved settings could not be verified"), "Ambiguous persistence failure was hidden")
	await begin()
	check(display.confirm().is_empty(), "Confirm rejected")
	store.finish("Connection lost after write")
	check(display.phase == "reconciling" and store.requests[-1][0] == "read", "Ambiguous save not reconciled")
	store.snapshot.saved = desired.duplicate()
	store.finish()
	check(display.phase == "idle" and display.applied == desired and surface.events[-1] == "confirm", "Committed save was incorrectly reverted")
	display.free()
	store.free()
	print("MGS_DISPLAY_SETTINGS_TEST failures=%d"%failures)
	quit(1 if failures else 0)
