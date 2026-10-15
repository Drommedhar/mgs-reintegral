extends SceneTree

const Actions = preload("res://options_actions.gd")
const Layout = preload("res://options_layout.gd")
var failures := 0
var completed := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func ack(id: int = 0, status: int = 0, epoch: int = 3) -> PackedByteArray:
	var data := PackedInt32Array([1,epoch,0,0,0,0,id,status]).to_byte_array()
	for index in 16: data[8+index]=7
	return data

func snapshot() -> Dictionary:
	return {"active":true,"epoch":3,"generation":7,"revision":1,"selection":1,"vibration":1,
		"controller_row":0,"controller_type":0,"reverse":0,"values":[0,0,1,0,0,0,0,0]}

func _initialize() -> void: run.call_deferred()

func client_checks() -> void:
	var actions := Actions.new()
	actions.supported=true
	actions.session_id.resize(16)
	actions.session_id.fill(7)
	var state := snapshot()
	actions.present(state)
	var copy: Dictionary = actions.get_snapshot()
	copy.values[1]=1
	check(actions.get_snapshot().values[1]==0,"Snapshot mutated provider")
	for request in [["bad",0,0],["set",1,2],["set",99,0],["back",1,0],["activate",1,0],["select",1,1]]:
		check(actions.request(request[0],request[1],request[2])==0,"Invalid action accepted: "+str(request))
	state.vibration=2
	actions.present(state)
	check(actions.request("set",5,1)==0,"Unsupported strong vibration accepted")
	state.vibration=0
	actions.present(state)
	check(actions.request("select",4)==0,"Unavailable vibration row accepted")
	state.vibration=1
	actions.present(state)
	check(actions.request("set",3,1)==1,"Valid sound change rejected")
	check(actions.request("back")==0,"Overlapping action accepted")
	var wire: PackedByteArray = actions.exchange(ack()).reply
	check(wire==PackedInt32Array([1,1,3,7,1,2,3,1]).to_byte_array(),"Wrong Options request identity or value")
	actions.action_finished.connect(func(_id,_error):completed+=1)
	actions.exchange(ack(1,2))
	check(completed==0,"Action finished before FRAME")
	state.values[3]=1
	state.revision=2
	actions.present(state)
	check(completed==1 and not actions.is_pending() and actions.get_snapshot().values[3]==1,"Completion did not include new native state")
	actions.exchange(ack(1,2))
	actions.present(state)
	check(completed==1,"Duplicate completion")
	check(actions.request("back")==2,"Second action rejected")
	check(actions.exchange(ack(1,2,4)).reply.decode_u32(4)==0,"Queued stale epoch was sent")
	actions.present({})
	check(completed==2 and not actions.last_error.is_empty(),"Stale epoch lacked result")
	var foreign := ack(1,2)
	foreign[8]=0
	check(actions.exchange(foreign).has("error"),"Foreign session accepted")
	check(actions.exchange(ack(99,2)).has("error"),"Unknown ack accepted")
	check(actions.exchange(ack(1,6)).has("error"),"Unknown status accepted")
	for page in [0,11]:
		state.selection=page
		actions.present(state)
		check(actions.request("back")==0,"Transition accepted action")
	state.selection=9
	actions.present(state)
	check(actions.request("set",0,3)==0 and actions.request("set",1,2)==0,"Invalid controller value accepted")
	actions.free()

func render_state(ui: Control, state: Dictionary) -> void:
	var view := state.duplicate(true)
	view.elements=[]
	view.texts={}
	for index in Layout.ELEMENTS.size():
		var item: Array = Layout.ELEMENTS[index]
		var shown: bool = index < 27 if state.selection not in [7,9] else index in range(27,31) if state.selection==7 else index in range(31,48)
		view.elements.append({"texture":Layout.texture_id(item[1]),"position":item[2].position,"size":item[2].size,"rgb":0x808080,"layer":1 if shown else 0,"blend":0})
	ui.apply_native_state(view)

func joy(button: int) -> void:
	for down in [true,false]:
		var event := InputEventJoypadButton.new()
		event.button_index=button
		event.pressed=down
		Input.parse_input_event(event)
		await process_frame

func run() -> void:
	client_checks()
	var directory := ProjectSettings.globalize_path("res://../../../.local/godot-content")
	var catalog = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("catalog.json")))
	var resources := preload("res://original_ui_assets.gd").new()
	resources.configure(directory,catalog.assets,int(catalog.disc))
	var builder := preload("res://options_scene.gd").new()
	var ui := builder.create(resources)
	check(ui!=null,"Cannot create Options UI: "+builder.error)
	if ui==null:
		quit(1)
		return
	root.add_child(ui)
	check(ui.bind_originals(resources).is_empty(),"Cannot bind local art")
	var actions := Actions.new()
	root.add_child(actions)
	actions.session_id.resize(16)
	actions.session_id.fill(7)
	actions.supported=true
	ui.connect_provider(actions)
	var state := snapshot()
	render_state(ui,state)
	actions.present(state)
	await process_frame
	var button: Button = ui.get_node("Options/Monaural/Interact")
	check(not button.disabled and actions.captures_input(),"Options did not own input")
	button.pressed.emit()
	var wire: PackedByteArray = actions.exchange(ack()).reply
	check(wire.decode_u32(20)==2 and wire.decode_u32(24)==3 and wire.decode_u32(28)==1,"Authored sound button did not set native value")
	check(button.disabled,"Pending button remained interactive")
	actions.exchange(ack(1,2))
	state.selection=3
	state.values[3]=1
	state.revision+=1
	render_state(ui,state)
	actions.present(state)
	await joy(JOY_BUTTON_DPAD_LEFT)
	wire=actions.exchange(ack(1,2)).reply
	check(wire.decode_u32(20)==2 and wire.decode_u32(24)==3 and wire.decode_u32(28)==0,"Controller did not select stereo")
	actions.exchange(ack(2,2))
	state.selection=9
	state.revision+=1
	render_state(ui,state)
	actions.present(state)
	await joy(JOY_BUTTON_B)
	wire=actions.exchange(ack(2,2)).reply
	check(wire.decode_u32(20)==2 and wire.decode_u32(24)==0 and wire.decode_u32(28)==1,"Controller mapping confirm failed")
	actions.exchange(ack(3,2))
	state.controller_type=1
	state.revision+=1
	actions.present(state)
	ui.get_node("Controller/TypeC/Interact").grab_focus()
	await joy(JOY_BUTTON_B)
	wire=actions.exchange(ack(3,2)).reply
	check(wire.decode_u32(20)==2 and wire.decode_u32(24)==0 and wire.decode_u32(28)==2,"Focused authored button was ignored by controller confirm")
	actions.exchange(ack(4,2))
	state.controller_type=2
	state.revision+=1
	actions.present(state)
	actions.suspend_input(true)
	check(ui.get_node("Controller/TypeB/Interact").disabled,"Display menu did not suspend Options")
	ui._request("set",0,1)
	check(ui.get_node("ActionError").visible and not ui.get_node("ActionError").text.is_empty(),"Rejected action has no visible feedback")
	actions.suspend_input(false)
	await joy(JOY_BUTTON_A)
	wire=actions.exchange(ack(4,2)).reply
	check(wire.decode_u32(20)==4,"Controller cancel did not request Back")
	actions.exchange(ack(5,2))
	actions.present({})
	check(not actions.captures_input(),"Closed Options retained input")
	ui.free()
	actions.free()
	print("MGS_OPTIONS_ACTIONS_TEST failures=%d"%failures)
	quit(1 if failures else 0)
