extends Node

signal settings_updated(snapshot: Dictionary)
signal request_finished(id: int, error: String)

var snapshot: Dictionary = {}
var unavailable_reason := "No launcher settings provider connected"
var last_error := ""
var display: Node
var _port := 0
var _token := ""
var _next_id := 0
var _active_id := 0
var _deadline := 0
var _peer: StreamPeerTCP
var _incoming := PackedByteArray()
var _outgoing := PackedByteArray()

func get_snapshot() -> Dictionary:
	var result := snapshot.duplicate(true)
	if result.is_empty() or display == null: return result
	result.display = display.snapshot()
	result.applied = result.display.applied
	result.live_apply = result.display.live_apply and unavailable_reason.is_empty()
	if result.live_apply:
		result.restart_required = []
		result.unapplied_saved = []
		for definition in result.definitions:
			definition.application = "live_confirm"
			if result.saved[definition.id] != result.applied.get(definition.id):
				result.unapplied_saved.append(definition.id)
	return result

func configure(port: String, token: String) -> String:
	if port.is_empty(): return unavailable_reason
	if not port.is_valid_int() or int(port)<1024 or int(port)>65535 or token.length()!=32 or not token.is_valid_hex_number():
		unavailable_reason = "Invalid settings provider port or session token"
		return unavailable_reason
	_port = int(port)
	_token = token
	unavailable_reason = ""
	return ""

func request(action: String, values: Dictionary = {}) -> int:
	last_error = unavailable_reason
	if not last_error.is_empty(): return 0
	if _active_id != 0: return _reject("A settings request is already pending")
	if action not in ["read", "validate", "save"]: return _reject("Unknown settings action")
	if action != "read" and snapshot.is_empty(): return _reject("Read settings before changing them")
	_next_id += 1
	if _next_id > 2147483647: _next_id = 1
	_active_id = _next_id
	var body := JSON.stringify({"schema":1,"id":_active_id,"token":_token,"action":action,"values":values,
		"revision":snapshot.get("revision","")}).to_utf8_buffer()
	if body.size()>4096:
		_active_id = 0
		return _reject("Settings request exceeds limit")
	_outgoing.resize(4)
	_outgoing.encode_u32(0,body.size())
	_outgoing.append_array(body)
	_incoming.clear()
	_deadline = Time.get_ticks_msec()+5000
	_peer = StreamPeerTCP.new()
	var error := _peer.connect_to_host("127.0.0.1",_port)
	if error != OK: _finish.call_deferred("Cannot connect to settings provider: "+error_string(error))
	return _active_id

func _reject(message: String) -> int:
	last_error = message
	return 0

func _process(_delta: float) -> void:
	if _active_id == 0: return
	if Time.get_ticks_msec()>=_deadline:
		_finish("Settings provider timed out")
		return
	_peer.poll()
	if _peer.get_status() == StreamPeerTCP.STATUS_CONNECTING: return
	if not _outgoing.is_empty() and _peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		_peer.set_no_delay(true)
		var sent := _peer.put_partial_data(_outgoing)
		if sent[0] != OK:
			_finish("Cannot send settings request")
			return
		_outgoing = _outgoing.slice(sent[1])
	var available := _peer.get_available_bytes()
	if available>65540-_incoming.size():
		_finish("Settings response exceeds limit")
		return
	if available:
		var received := _peer.get_data(available)
		if received[0]!=OK:
			_finish("Cannot read settings response")
			return
		_incoming.append_array(received[1])
	if _incoming.size()>=4:
		var size := _incoming.decode_u32(0)
		if size<2 or size>65536 or _incoming.size()>size+4:
			_finish("Invalid settings response length")
			return
		if _incoming.size()==size+4:
			_finish(_accept(_incoming.slice(4)))
			return
	if _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED: _finish("Settings provider disconnected before its response")

func _accept(data: PackedByteArray) -> String:
	var parsed = JSON.parse_string(data.get_string_from_utf8())
	if not parsed is Dictionary or parsed.get("schema")!=1 or parsed.get("id")!=_active_id or not parsed.get("error") is String:
		return "Invalid settings response identity"
	if not parsed.error.is_empty(): return parsed.error
	var next = parsed.get("snapshot")
	if not next is Dictionary or next.get("schema")!=1 or not next.get("revision") is String:
		return "Invalid settings snapshot"
	for key in ["launch","saved"]:
		if not next.get(key) is Dictionary: return "Missing settings values: "+key
	if not next.get("definitions") is Array or not next.get("restart_required") is Array or not next.get("live_apply") is bool:
		return "Invalid settings definitions"
	var error := _validate_values(next)
	if not error.is_empty(): return error
	snapshot = next.duplicate(true)
	settings_updated.emit(get_snapshot())
	return ""

func _validate_values(next: Dictionary) -> String:
	var ids := {}
	for definition in next.definitions:
		if not definition is Dictionary or not definition.get("id") is String or ids.has(definition.id): return "Invalid setting ID"
		for key in ["label","owner","application"]:
			if not definition.get(key) is String: return "Invalid setting definition: "+key
		var kind: int = TYPE_STRING if definition.get("type")=="string" else TYPE_BOOL if definition.get("type")=="boolean" else TYPE_NIL
		if kind == TYPE_NIL: return "Unsupported setting type"
		for key in ["launch","saved"]:
			if typeof(next[key].get(definition.id))!=kind: return "Invalid setting value: "+definition.id
		ids[definition.id] = true
	if ids.size()!=next.launch.size() or ids.size()!=next.saved.size(): return "Settings values do not match definitions"
	for id in next.restart_required:
		if not id is String or not ids.has(id): return "Unknown restart setting"
	return ""

func _finish(error: String) -> void:
	if _active_id == 0: return
	var id := _active_id
	_active_id = 0
	last_error = error
	_peer.disconnect_from_host()
	_peer = null
	_incoming.clear()
	_outgoing.clear()
	request_finished.emit(id,error)

func _exit_tree() -> void:
	if _active_id: _finish("Settings session closed")
