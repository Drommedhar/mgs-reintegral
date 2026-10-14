extends Node

var actions: Node
var runtime: Node
var ui: Control
var finished_id := 0
var result := ""
var failures := 0

func _ready() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures+=1

func wait_for(predicate: Callable, message: String) -> bool:
	var deadline := Time.get_ticks_msec()+30000
	while not predicate.call() and Time.get_ticks_msec()<deadline: await get_tree().process_frame
	check(predicate.call(),message+": "+JSON.stringify(actions.get_snapshot()))
	return predicate.call()

func mouse_click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position=point
	Input.parse_input_event(motion)
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=point
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=down
		Input.parse_input_event(event)
		await get_tree().process_frame

func click(path: String, joy_button: int = -1) -> bool:
	var button: Button = ui.get_node(path)
	check(button.is_visible_in_tree() and not button.disabled,"Unavailable button: "+path)
	if failures: return false
	var before := finished_id
	if joy_button>=0:
		button.grab_focus()
		for down in [true,false]:
			var event := InputEventJoypadButton.new()
			event.button_index=joy_button
			event.pressed=down
			Input.parse_input_event(event)
			await get_tree().process_frame
	else: await mouse_click(button)
	if not await wait_for(func():return finished_id>before,"No acknowledgement for "+path): return false
	check(result.is_empty(),"Native rejected action: "+result)
	print("MGS_CODEC_CLICK %s id=%d input=%s values=%s"%[path,finished_id,"controller" if joy_button>=0 else "mouse",JSON.stringify(actions.get_snapshot().get("values",[]))])
	return result.is_empty()

func run() -> void:
	var api := get_tree().get_first_node_in_group("mgs_visual_api_v1")
	if api.has_meta("codec_actions_probe_started"): return
	api.set_meta("codec_actions_probe_started",true)
	reparent(get_tree().root)
	actions=api.get_codec_actions()
	runtime=actions.get_parent()
	ui=runtime.codec.ui
	actions.action_finished.connect(func(id,error):finished_id=id;result=error)
	if await wait_for(func():return runtime.native_context.current.get("stage","") in ["s00a","s01a"] and actions.get_snapshot().get("active",false),"Codec provider unavailable"):
		if actions.get_snapshot().get("opened",false): await finish_call()
		if idle(): await request("back")
	if await wait_for(func():return runtime.scene_view.current_instances>0 and actions.get_snapshot().get("allowed",0)&2,"Native Codec cannot open from gameplay"):
		var tick: int = runtime.native_context.current.actor_loop_tick
		await wait_for(func():return runtime.native_context.current.actor_loop_tick>=tick+30,"Gameplay did not settle")
		if await wait_for(func():return actions.get_snapshot().get("allowed",0)&2,"Native Codec became unavailable"):
			await exercise()
	print("MGS_CODEC_ACTIONS_LIVE failures=%d frames=%d"%[failures,runtime.frame_number])
	runtime.request_close()

func request(action: String, target: int = 0) -> bool:
	var id: int = actions.request(action,target)
	check(id>0,"Codec rejected "+action+": "+actions.last_error)
	if not id or not await wait_for(func():return finished_id==id,"Codec action not acknowledged: "+action): return false
	check(result.is_empty(),"Codec action failed: "+result)
	return result.is_empty()

func idle() -> bool:
	return actions.get_snapshot().get("mode",0)==1 and actions.get_snapshot().get("allowed",0)&4

func exercise() -> void:
	if not await request("open"): return
	if not await wait_for(idle,"Codec tuning did not open"): return
	check(actions.captures_input(),"Codec did not capture input")
	var frequency: int = actions.get_snapshot().frequency
	if not await click("Panel/Console/LeftButton"): return
	check(actions.get_snapshot().frequency==14000+posmod(frequency-14000-1,200),"Left tuning failed")
	if not await click("Panel/Console/RightButton",JOY_BUTTON_B): return
	check(actions.get_snapshot().frequency==frequency,"Right tuning failed")
	if not await click("Panel/Console/MemoryButton"): return
	if not await wait_for(func():return actions.get_snapshot().get("mode",0)==10 and actions.get_snapshot().get("allowed",0)&512,"Contacts did not finish opening"): return
	if actions.get_snapshot().count>0:
		if not await request("select",0): return
	if not await click("Panel/BackButton"): return
	if not await wait_for(idle,"Contacts Back did not return to tuning"): return
	if not await request("tune",14085): return
	if not await click("Panel/Console/CallButton"): return
	if not await wait_for(func():return actions.get_snapshot().get("allowed",0)&384,"Call never reached dialogue"): return
	check(actions.get_snapshot().mode!=9,"Campbell returned NO RESPONSE instead of dialogue")
	for frame in 3: await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.generated/codec-actions-live")
	check(runtime.get_viewport().get_texture().get_image().save_png("res://.generated/codec-actions-live/dialogue.png")==OK,"Cannot save Codec proof image")
	await finish_call()
	if not await contact_call(): return
	if not await click("Panel/BackButton",JOY_BUTTON_A): return
	if not await wait_for(func():return not actions.get_snapshot().get("opened",true),"Codec did not close"): return
	check(not actions.captures_input(),"Closed Codec retained input")
	var tick: int = runtime.native_context.current.actor_loop_tick
	await wait_for(func():return runtime.native_context.current.actor_loop_tick>=tick+6,"Game did not resume")

func contact_call() -> bool:
	if not await click("Panel/Console/MemoryButton"): return false
	if not await wait_for(func():return actions.get_snapshot().get("mode",0)==10 and actions.get_snapshot().get("allowed",0)&64,"Contacts cannot confirm"): return false
	var contacts: PackedInt32Array = runtime.codec.state.current.contacts
	var index := contacts.find(14085)
	check(index>=0,"Campbell is missing from the first contacts page")
	if index<0 or not await click("Panel/Contacts/Contact%d/Interact"%index): return false
	if not await wait_for(func():return actions.get_snapshot().get("allowed",0)&384,"Contact selection never reached dialogue"): return false
	check(actions.get_snapshot().frequency==14085 and actions.get_snapshot().mode!=9,"Contact confirmed the wrong call")
	await finish_call()
	return not failures

func finish_call() -> void:
	var deadline := Time.get_ticks_msec()+90000
	var advances := 0
	var skips := 0
	while actions.get_snapshot().get("opened",false) and not idle() and Time.get_ticks_msec()<deadline:
		var state: Dictionary = actions.get_snapshot()
		if state.get("allowed",0)&256:
			if not await click("Panel/SkipButton"): return
			skips+=1
		elif state.get("allowed",0)&128:
			if not await click("Panel/AdvanceButton",JOY_BUTTON_B): return
			advances+=1
		else: await get_tree().process_frame
	check(idle() or not actions.get_snapshot().get("opened",false),"Call did not finish")
	print("MGS_CODEC_DIALOGUE skips=%d advances=%d"%[skips,advances])
