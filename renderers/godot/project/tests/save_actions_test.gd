extends SceneTree

const Actions = preload("res://save_actions.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func client() -> Node:
	var actions := Actions.new()
	actions.session_id.resize(16)
	actions.session_id.fill(7)
	actions.supported = true
	return actions

func snapshot() -> Dictionary:
	return {"epoch":3,"active":true,"generation":1,"revision":2,"state":0,"message":0,
		"selected_id":7,"can_create":true,"cursor":0,"loading":false,
		"entries":[{"id":7,"location":"Dock","metadata_valid":1,"hours":1,"minutes":24,"difficulty":2,"completion":0}]}

func ack(id: int = 0, status: int = 0, epoch: int = 3) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(32)
	for pair in [[0,1],[4,epoch],[24,id],[28,status]]: data.encode_u32(pair[0],pair[1])
	for index in 16: data[8+index]=7
	return data

func wire_checks() -> void:
	var actions := client()
	check(actions.request("new_save")==0,"Inactive dialog accepted action")
	actions.present(snapshot())
	check(actions.capture_input(true).is_empty() and actions.captures_input(),"Active capture failed")
	var copy: Dictionary = actions.get_snapshot()
	copy.entries.clear()
	check(actions.get_snapshot().entries.size()==1,"Snapshot exposed mutable state")
	for pair in [["unknown",0],["activate",0],["activate",99],["confirm",0],["continue",0],["new_save",7],["back",7]]:
		check(actions.request(pair[0],pair[1])==0,"Invalid action accepted: "+str(pair))
	var results := []
	actions.action_finished.connect(func(id,error):results.append([id,error,actions.get_snapshot().get("state",-1)]))
	var id: int = actions.request("activate",7)
	check(id>0 and actions.request("back")==0,"Overlapping action accepted")
	var reply: PackedByteArray = actions.exchange(ack()).reply
	check(reply.to_int32_array()==PackedInt32Array([1,id,3,1,2,0,0,7,2,7]),"Native request lost catalog/dialog identity")
	actions.exchange(ack(id,1))
	check(actions.is_pending() and results.is_empty(),"Pending acknowledged as completion")
	actions.exchange(ack(id,2))
	check(actions.is_pending() and results.is_empty(),"Action committed before FRAME")
	var state := snapshot()
	state.state=2
	actions.present(state)
	check(results==[[id,"",2]] and not actions.is_pending(),"FRAME result/order wrong")
	actions.exchange(ack(id,2))
	actions.present(state)
	check(results.size()==1,"Duplicate native acknowledgement emitted result twice")
	check(actions.request("new_save")==0,"New Save accepted during confirmation")
	id=actions.request("back")
	check(id>0,"Confirmation cancellation unavailable")
	actions.exchange(ack(id-1,2,4))
	actions.present({})
	check(results.size()==2 and not results[-1][1].is_empty() and not actions.captures_input(),"Stale epoch did not fail/release capture")
	for data in [ack().slice(0,-1),ack(999,2),ack(0,1)]:
		check(actions.exchange(data).has("error"),"Malformed acknowledgement accepted")
	var foreign := ack(id-1,2)
	foreign[8]=0
	check(actions.exchange(foreign).has("error"),"Foreign session accepted")
	actions.present(snapshot())
	actions.suspend_input(true)
	check(actions.request("back")==0 and not actions.captures_input(),"Another menu leaked save input")
	actions.suspend_input(false)
	state=snapshot()
	state.state=3
	actions.present(state)
	check(actions.request("back")==0,"Busy operation cancellable")
	state=snapshot()
	state.loading=true
	state.can_create=false
	actions.present(state)
	check(actions.request("new_save")==0,"Load dialog offered New Save")
	actions.free()

func _initialize() -> void: run.call_deferred()

func joy(button: int) -> void:
	for down in [true,false]:
		var event := InputEventJoypadButton.new()
		event.button_index=button
		event.pressed=down
		Input.parse_input_event(event)
		await process_frame

func run() -> void:
	wire_checks()
	var directory := ProjectSettings.globalize_path("res://../../../.local/godot-content")
	var catalog = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("catalog.json")))
	var presenter := preload("res://save_presenter.gd").new()
	root.add_child(presenter)
	check(presenter.initialize({},directory,catalog.assets,1).is_empty(),"Cannot initialize interactive saves")
	var ui: Control = presenter.ui
	for path in ["Dialog/Confirm","Dialog/Cancel","Dialog/Continue"]:
		var button: Button = ui.get_node(path)
		check(button.position.y+button.size.y<ui.get_node("Dialog").size.y,"Confirmation button exceeds dialog: %s size=%s minimum=%s font=%d"%[path,button.size,button.get_combined_minimum_size(),button.get_theme_font_size("font_size")])
	var actions := client()
	root.add_child(actions)
	ui.connect_provider(actions)
	presenter.show()
	var state := snapshot()
	for index in range(8,16):
		var entry: Dictionary = state.entries[0].duplicate()
		entry.id=index
		entry.location="Save %d"%index
		state.entries.append(entry)
	ui.apply_native_state(state)
	actions.present(state)
	check(actions.captures_input() and ui.get_node("SaveList/Save0/Activate").has_focus(),"Save menu did not capture/focus")
	for index in 8: ui._move_cursor(1)
	check(ui.get_node("SaveList/Save5/Location").text=="Save 15","Scrolling skipped last save")
	ui.get_node("SaveList/Save5/Activate").pressed.emit()
	var reply: PackedByteArray = actions.exchange(ack()).reply
	check(reply.decode_u32(32)==2 and reply.decode_u32(36)==15,"Button did not activate visible stable ID")
	check(ui.get_node("NewSave/Activate").disabled,"Pending action left destructive controls enabled")
	state.state=2
	state.message=2
	actions.exchange(ack(reply.decode_u32(4),2))
	ui.apply_native_state(state)
	actions.present(state)
	check(ui.get_node("Dialog/Cancel").has_focus(),"Overwrite did not default to Cancel")
	ui.get_node("Dialog/Cancel").pressed.emit()
	var back: PackedByteArray = actions.exchange(ack(reply.decode_u32(4),2)).reply
	check(back.decode_u32(32)==5,"Cancel button did not invoke native back action")
	state.state=0
	actions.exchange(ack(back.decode_u32(4),2))
	ui.apply_native_state(state)
	actions.present(state)
	ui._move_cursor(1)
	check(ui.get_node("NewSave/Activate").has_focus(),"Last row did not reach New Save")
	ui.get_node("NewSave/Activate").pressed.emit()
	var fresh: PackedByteArray = actions.exchange(ack(back.decode_u32(4),2)).reply
	check(fresh.decode_u32(32)==3 and fresh.decode_u32(36)==0,"New Save button wrong action")
	actions.exchange(ack(fresh.decode_u32(4),3))
	actions.present(state)
	check(ui.get_node("Error").visible and not ui.get_node("NewSave/Activate").disabled,"Stale selection did not show actionable error")
	await joy(JOY_BUTTON_DPAD_UP)
	check(ui.get_node("SaveList/Save5/Activate").has_focus(),"Controller did not focus last saved game")
	check(not ui.get_node("SaveList/Save5/Activate").disabled,"Focused save button disabled")
	await joy(JOY_BUTTON_B)
	var controller: PackedByteArray = actions.exchange(ack(fresh.decode_u32(4),3)).reply
	check(controller.decode_u32(32)==2 and controller.decode_u32(36)==15,"Controller accept did not activate focused save: "+str(controller.to_int32_array()))
	if failures:
		presenter.free()
		actions.free()
		quit(1)
		return
	actions.exchange(ack(controller.decode_u32(4),2))
	state.state=2
	ui.apply_native_state(state)
	actions.present(state)
	await joy(JOY_BUTTON_B)
	var cancel: PackedByteArray = actions.exchange(ack(controller.decode_u32(4),2)).reply
	check(cancel.decode_u32(32)==5,"Controller default acceptance overwrote instead of cancelling")
	actions.exchange(ack(cancel.decode_u32(4),2))
	state.state=0
	ui.apply_native_state(state)
	actions.present(state)
	actions.suspend_input(true)
	check(ui.get_node("NewSave/Activate").disabled,"Display menu did not suspend save buttons")
	actions.suspend_input(false)
	check(not ui.get_node("NewSave/Activate").disabled,"Save buttons did not resume after display menu")
	actions.present({})
	check(not actions.captures_input(),"Closed dialog retained input capture")
	presenter.free()
	actions.free()
	print("MGS_SAVE_ACTIONS_TEST failures=%d"%failures)
	quit(1 if failures else 0)
