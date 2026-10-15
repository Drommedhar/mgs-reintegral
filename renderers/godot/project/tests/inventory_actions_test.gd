extends SceneTree

const Actions = preload("res://inventory_actions.gd")
const Ui = preload("res://inventory_ui.gd")
const ButtonScript = preload("res://inventory_button.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures+=1

func packet(id: int = 0, status: int = 0) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(652)
	var words := [1,3,0,0,0,0,id,status,7,1,1,1,1,0,60,3,13,-1,-1,
		0,-1,1,1,0,13,2,3,0,2,1,0]
	for index in words.size(): data.encode_s32(index*4,words[index])
	for index in 16: data[8+index]=7
	return data

func _initialize() -> void: run.call_deferred()

func controls_checks() -> void:
	var ui := Ui.new()
	root.add_child(ui)
	var provider := Actions.new()
	provider.supported=true
	root.add_child(provider)
	var button := ButtonScript.new()
	button.native_action="use"
	ui.add_child(button)
	ui.connect_provider(provider)
	var state := {"epoch":3,"generation":7,"revision":1,"active":true,"mode":1,"owned":0,"allowed":60,"selection":13,
		"entries":[{"side":0,"id":-1,"quantity":1,"flags":1},{"side":0,"id":13,"quantity":2,"flags":3}]}
	provider.present(state)
	check(not provider.captures_input(),"Native held-button inventory lost control before a Godot action")
	state.owned=1
	provider.present(state)
	check(provider.captures_input() and not button.disabled,"Godot inventory did not capture input")
	button.pressed.emit()
	check(provider._queued==PackedInt32Array([1,1,3,7,1,4,0,13]).to_byte_array(),"Use Button did not send the current item")
	provider._result=2
	provider.present(state)
	ui.controls.navigate("ui_cancel")
	check(provider._queued==PackedInt32Array([1,2,3,7,1,5,0,0]).to_byte_array(),"Cancel did not request native close/equip")
	provider._result=2
	state.mode=0
	state.owned=0
	provider.present(state)
	check(not provider.captures_input(),"Closed inventory retained gameplay input")
	ui.free()
	provider.free()

func run() -> void:
	controls_checks()
	var provider := Actions.new()
	provider.supported=true
	provider.session_id.resize(16)
	provider.session_id.fill(7)
	check(provider.exchange_view(packet(),{"epoch":4}).has("error"),"Wrong inventory epoch accepted")
	check(not provider.exchange_view(packet(),{"epoch":3}).has("error"),"Valid inventory rejected")
	check(provider.get_snapshot().is_empty(),"Inventory appeared before FRAME")
	provider.present_pending(3,true)
	for request in [["equip",0,2],["use",0,2],["select",0,23],["use",1,0],["open",2,0],["close",0,13]]:
		check(not provider.request(request[0],request[1],request[2]),"Invalid inventory request accepted: "+str(request))
	check(provider.request("equip",0,-1)==1,"Unequip request rejected")
	check(not provider.request("use",0,13),"Overlapping use accepted")
	check(provider.exchange_view(packet(),{"epoch":3}).reply==PackedInt32Array([1,1,3,7,1,3,0,-1]).to_byte_array(),"Incorrect signed inventory target")
	provider.exchange_view(packet(1,2),{"epoch":3})
	check(provider.is_pending(),"Inventory completed before FRAME")
	provider.present_pending(3,true)
	check(not provider.is_pending(),"Inventory acknowledgement lost")
	for change in [[0,2],[8,0],[32,0],[36,0],[40,2],[44,3],[48,2],[52,4],[56,64],[60,37],[64,24],[68,24],[72,10],[76,2],[80,24],[88,4],[128,1]]:
		var bad := packet(1,2)
		bad.encode_u32(change[0],change[1])
		check(provider.exchange_view(bad,{"epoch":3}).has("error"),"Malformed inventory action view accepted: "+str(change))
	provider.present_pending(4,true)
	check(not provider.request("use",0,13) and not provider.captures_input(),"Stale inventory retained actions/input")
	provider.free()
	print("INVENTORY ACTIONS TEST failures=%d"%failures)
	quit(1 if failures else 0)
