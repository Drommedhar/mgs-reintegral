extends SceneTree

const Actions = preload("res://title_actions.gd")
var failures := 0
var completed := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func ack(id: int = 0, status: int = 0) -> PackedByteArray:
	var data := PackedInt32Array([1,3,0,0,0,0,id,status]).to_byte_array()
	for index in 16: data[8+index]=7
	return data

func _initialize() -> void:
	var actions := Actions.new()
	actions.supported=true
	actions.session_id.resize(16)
	actions.session_id.fill(7)
	var state := {"active":true,"epoch":3,"generation":7,"revision":1,"mode":7,"selection":0,"difficulty":2,"extreme":false,"storage_choice":0}
	actions.present(state)
	for request in [["bad",0],["select",5],["back",1],["activate",-1]]:
		check(actions.request(request[0],request[1])==0,"Invalid action accepted: "+str(request))
	check(actions.request("activate",0)==1,"New game action rejected")
	check(actions.request("back")==0,"Overlapping action accepted")
	check(actions.exchange(ack()).reply==PackedInt32Array([1,1,3,7,1,2,0]).to_byte_array(),"Wrong title wire request")
	actions.action_finished.connect(func(_id,_error):completed+=1)
	actions.exchange(ack(1,2))
	check(completed==0,"Completed before FRAME")
	state.mode=21
	state.revision=2
	actions.present(state)
	check(completed==1 and not actions.is_pending(),"Completion missing")
	check(actions.request("select",4)==0,"Locked Extreme accepted")
	state.extreme=true
	actions.present(state)
	check(actions.validate("select",4).is_empty(),"Unlocked Extreme rejected")
	state.revision=0
	actions.present(state)
	check(actions.request("back")==0,"Transition accepted Back")
	state.revision=3
	for mode in [2,3,8,10,11,12,13,20]:
		state.mode=mode
		actions.present(state)
		check(actions.request("activate")==0,"Unsupported page accepted action")
	for mode in [0,1,4,5,6]:
		state.mode=mode
		actions.present(state)
		check(actions.validate("activate",0).is_empty(),"Press Start rejected")
		check(actions.request("back")==0,"Press Start accepted Back")
	for mode in [18,19]:
		state.mode=mode
		actions.present(state)
		check(actions.validate("activate",1).is_empty() and not actions.validate("select",2).is_empty(),"Storage choice limits")
	actions.capture_input(true)
	actions.suspend_input(true)
	check(not actions.captures_input() and actions.request("back")==0,"Display suspension ignored")
	actions.suspend_input(false)
	actions.present({})
	check(not actions.captures_input(),"Capture retained after close")
	var foreign := ack(1,2)
	foreign[8]=0
	check(actions.exchange(foreign).has("error"),"Foreign session accepted")
	actions.free()
	print("Title actions: %d failures" % failures)
	quit(1 if failures else 0)
