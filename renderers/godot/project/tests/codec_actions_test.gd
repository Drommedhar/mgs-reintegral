extends SceneTree

const Actions = preload("res://codec_actions.gd")
const Ui = preload("res://codec_ui.gd")
const ActionButton = preload("res://codec_button.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures+=1

func packet(id: int = 0, status: int = 0) -> PackedByteArray:
	var data := PackedInt32Array([1,3,0,0,0,0,id,status,7,1,1,1,1,14085,1022,0,4]).to_byte_array()
	for index in 16: data[8+index]=7
	return data

func _initialize() -> void:
	call_deferred("run")

func controls_checks() -> void:
	var ui := Ui.new()
	root.add_child(ui)
	var provider := Actions.new()
	provider.supported=true
	root.add_child(provider)
	var confirm := ActionButton.new()
	confirm.native_action="confirm"
	confirm.native_target=-1
	ui.add_child(confirm)
	ui.connect_provider(provider)
	var state := {"epoch":3,"generation":7,"revision":1,"active":true,"opened":true,"mode":16,"frequency":14085,"allowed":96,"selection":1,"count":3}
	provider.present(state)
	check(provider.captures_input() and confirm.visible and not confirm.disabled,"Prompt controls unavailable")
	ui.controls.navigate("ui_down")
	check(provider._queued==PackedInt32Array([1,1,3,7,1,5,2]).to_byte_array(),"Prompt navigation did not select the next native choice")
	provider._result=2
	state.selection=2
	state.revision=2
	provider.present(state)
	confirm.pressed.emit()
	check(provider._queued==PackedInt32Array([1,2,3,7,2,6,2]).to_byte_array(),"Prompt button did not confirm the selected native choice")
	provider._result=2
	provider.present(state)
	for mode in [12,14]:
		state.mode=mode
		state.allowed=0
		provider.present(state)
		check(not provider.captures_input() and not confirm.visible,"Codec stole input from Save/Load")
	state.mode=1
	state.allowed=540
	provider.present(state)
	check(provider.captures_input(),"Codec did not regain input after Save/Load")
	provider.suspend_input(true)
	check(not provider.captures_input(),"Suspended Codec retained input")
	provider.suspend_input(false)
	state.opened=false
	state.mode=21
	state.allowed=2
	provider.present(state)
	check(not provider.captures_input(),"Closed Codec stole gameplay input")
	ui.controls.artwork={"memory_top":8}
	check(ui.controls.command("contact",3)==["confirm",11],"Contact click ignored the visible native page")
	provider.free()
	ui.free()

func run() -> void:
	controls_checks()
	var provider := Actions.new()
	provider.supported=true
	provider.session_id=PackedByteArray()
	provider.session_id.resize(16)
	provider.session_id.fill(7)
	check(provider.exchange_view(packet(),{"epoch":4}).has("error"),"Wrong Codec epoch accepted")
	check(not provider.exchange(packet()).has("error"),"Valid Codec view rejected")
	check(provider.get_snapshot().is_empty(),"Codec view presented before FRAME")
	provider.present_pending(3,true)
	for request in [["tune",13999],["tune",14200],["confirm",4],["call",1],["unknown",0]]:
		check(provider.request(request[0],request[1])==0,"Invalid request accepted")
	check(provider.request("tune",14199)==1,"Valid tune rejected")
	check(provider.request("back")==0,"Overlapping request accepted")
	check(provider.exchange(packet()).reply==PackedInt32Array([1,1,3,7,1,2,14199]).to_byte_array(),"Incorrect Codec request layout")
	provider.exchange(packet(1,2))
	check(provider.is_pending(),"Completed before resulting FRAME")
	provider.present_pending(3,true)
	check(not provider.is_pending(),"Missing Codec completion")
	for change in [[0,2],[8,0],[32,0],[36,0],[40,2],[44,2],[48,22],[52,13000],[56,1024],[60,33],[64,33]]:
		var invalid := packet(1,2)
		invalid.encode_u32(change[0],change[1])
		check(provider.exchange(invalid).has("error"),"Malformed Codec action view accepted: "+str(change))
	var locked := packet(1,2)
	locked.encode_u32(56,0)
	provider.exchange(locked)
	provider.present_pending(3,true)
	check(provider.request("skip")==0,"Locked dialogue skip accepted")
	provider.present_pending(4,true)
	check(provider.request("call")==0 and not provider.captures_input(),"Stale Codec retained actions/input")
	provider.free()
	print("CODEC ACTIONS TEST failures=%d"%failures)
	quit(1 if failures else 0)
