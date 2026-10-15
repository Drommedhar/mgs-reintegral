extends Node

signal state_changed(state: Dictionary)
signal action_finished(id: int, error: String)

var _label := "Menu"
var _word_count := 0
var _errors: Dictionary = {}
var session_id := PackedByteArray()
var supported := false
var last_error := ""
var _current: Dictionary = {}
var _next_id := 0
var _active_id := 0
var _sent_id := 0
var _queued := PackedByteArray()
var _result := 0
var _capture := false
var _suspended := false

func get_snapshot() -> Dictionary:
	return _current.duplicate(true)

func capture_input(active: bool) -> String:
	if active and (not supported or not _current.get("active",false)):
		return "%s input capture requires an active supported dialog" % _label
	_capture = active
	return ""

func captures_input() -> bool:
	return _capture and not _suspended and supported and _current.get("active",false)

func suspend_input(active: bool) -> void:
	_suspended = active
	state_changed.emit(get_snapshot())

func is_pending() -> bool:
	return _active_id != 0

func _can_request() -> bool:
	last_error = ""
	if not supported or not _current.get("active",false): _reject("No active native %s dialog" % _label)
	elif _suspended: _reject("Another menu has input focus")
	elif _active_id: _reject("A %s action is already pending" % _label)
	return last_error.is_empty()

func _enqueue(words: Array) -> int:
	if _next_id == 0xffffffff: return _reject("Menu action IDs exhausted; restart the session")
	_next_id += 1
	_active_id = _next_id
	_queued = PackedInt32Array([1,_active_id] + words).to_byte_array()
	return _active_id

func _reject(message: String) -> int:
	last_error = message
	return 0

func exchange(data: PackedByteArray) -> Dictionary:
	if data.size() != 32 or data.decode_u32(0) != 1: return {"error":"Invalid %s action response layout" % _label}
	if session_id.size() != 16 or data.slice(8,24) != session_id: return {"error":"%s action session mismatch" % _label}
	var id := data.decode_u32(24)
	var status := data.decode_u32(28)
	if id != _sent_id or status > 5 or (id == 0 and status != 0) or (id != 0 and status == 0):
		return {"error":"Invalid %s action acknowledgement" % _label}
	if id == _active_id and status >= 2: _result = status
	var reply := PackedByteArray()
	reply.resize(_word_count * 4)
	reply.encode_u32(0,1)
	if not _queued.is_empty():
		if _queued.decode_u32(8) != data.decode_u32(4):
			_result = 3
		else:
			reply = _queued
			_sent_id = _active_id
		_queued = PackedByteArray()
	return {"reply":reply}

func present(state: Dictionary) -> void:
	var changed := _current != state
	_current = state.duplicate(true)
	if not _current.get("active",false): _capture = false
	if changed: state_changed.emit(get_snapshot())
	if _result:
		var id := _active_id
		last_error = _errors.get(_result, "")
		_active_id = 0
		_result = 0
		action_finished.emit(id, last_error)
