extends SceneTree

var failures := 0
var client := preload("res://settings_client.gd").new()

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func send(action: String, values: Dictionary = {}) -> String:
	var id := client.request(action,values)
	if id == 0: return client.last_error
	var result: Array = await client.request_finished
	check(result[0]==id,"Settings response ID changed")
	return result[1]

func malformed_responses() -> void:
	var before := client.snapshot.duplicate(true)
	client._active_id = 17
	var response := {"schema":1,"id":17,"error":"","snapshot":before.duplicate(true)}
	response.snapshot.saved["display.fullscreen"] = 1
	check(not client._accept(JSON.stringify(response).to_utf8_buffer()).is_empty(),"Wrong response value type accepted")
	response.snapshot = before.duplicate(true)
	response.id = 18
	check(not client._accept(JSON.stringify(response).to_utf8_buffer()).is_empty(),"Wrong response ID accepted")
	response.id = 17
	response.snapshot.restart_required = ["unknown"]
	check(not client._accept(JSON.stringify(response).to_utf8_buffer()).is_empty(),"Unknown restart setting accepted")
	check(client.snapshot==before,"Rejected response changed retained settings")
	client._active_id = 0

func run() -> void:
	root.add_child(client)
	check(client.request("read")==0 and not client.last_error.is_empty(),"Missing host silently accepted")
	check(not client.configure("7","00".repeat(16)).is_empty(),"Invalid port accepted")
	var args := OS.get_cmdline_user_args()
	if args.size()!=1:
		push_error("Pass the live settings fixture directory")
		quit(1)
		return
	var host = JSON.parse_string(FileAccess.get_file_as_string(args[0].path_join("ready.json")))
	check(client.configure(str(int(host.port)),OS.get_environment("MGS_GODOT_SESSION_TOKEN")).is_empty(),"Settings client configure failed")
	check(client.request("save",{"display.fullscreen":true})==0,"Save accepted without a revision")
	check((await send("read")).is_empty(),"Read failed: "+client.last_error)
	if client.snapshot.is_empty():
		quit(1)
		return
	check(client.snapshot.definitions.size()==3,"Display definitions missing")
	check(client.snapshot.saved["display.resolution"]=="1280x720","Launcher settings not read")
	var original := FileAccess.get_file_as_string(args[0].path_join("settings.xml"))
	var changes := {"display.resolution":"1920x1080","display.fullscreen":true}
	check((await send("validate",changes)).is_empty(),"Candidate rejected")
	check(client.snapshot.candidate["display.fullscreen"] and client.snapshot.saved["display.fullscreen"]==false,"Validation changed saved state")
	check(FileAccess.get_file_as_string(args[0].path_join("settings.xml"))==original,"Validation wrote settings")
	check(not (await send("save",{"display.fullscreen":1})).is_empty(),"Wrong type accepted")
	check(client.snapshot.saved["display.fullscreen"]==false,"Rejected request changed snapshot")
	var old_revision: String = client.snapshot.revision
	check((await send("save",changes)).is_empty(),"Save failed: "+client.last_error)
	check(client.snapshot.saved["display.fullscreen"] and client.snapshot.restart_required.size()==2,"Restart requirements missing")
	check(client.snapshot.launch["display.resolution"]=="1280x720" and not client.snapshot.live_apply,"Persistence claimed live application")
	var saved := FileAccess.get_file_as_string(args[0].path_join("settings.xml"))
	check(saved.contains("<Resolution>1920x1080</Resolution>") and saved.contains("keep.me"),"Shared storage or mod preservation failed")
	client.snapshot.revision = old_revision
	check(not (await send("save",{"display.fullscreen":false})).is_empty(),"Stale write accepted")
	check(FileAccess.get_file_as_string(args[0].path_join("settings.xml"))==saved,"Stale write changed storage")
	check((await send("read")).is_empty(),"Reload after stale request failed")
	check((await send("save",client.snapshot.launch)).is_empty(),"Restore failed")
	check(client.snapshot.restart_required.is_empty(),"Restore retained restart requirements")
	check((await send("save",changes)).is_empty(),"Next-launch fixture save failed")
	malformed_responses()
	client.queue_free()
	await process_frame
	print("SETTINGS CLIENT TEST failures=%d"%failures)
	quit(1 if failures else 0)
