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
	print("MGS_OPTIONS_CLICK %s id=%d input=%s values=%s"%[path,finished_id,"controller" if joy_button>=0 else "mouse",JSON.stringify(actions.get_snapshot().get("values",[]))])
	return result.is_empty()

func run() -> void:
	var api := get_tree().get_first_node_in_group("mgs_visual_api_v1")
	if api.has_meta("options_probe_started"): return
	api.set_meta("options_probe_started",true)
	reparent(get_tree().root)
	actions=api.get_options_actions()
	runtime=actions.get_parent()
	ui=runtime.options.ui
	actions.action_finished.connect(func(id,error):finished_id=id;result=error)
	if await wait_for(func():return actions.get_snapshot().get("selection",0)==1,"Options did not finish opening"):
		await exercise()
	print("MGS_OPTIONS_ACTIONS_LIVE failures=%d frames=%d"%[failures,runtime.frame_number])
	runtime.request_close()

func exercise() -> void:
	check(actions.captures_input(),"Options does not own input")
	if not await click("Options/Monaural/Interact"): return
	check(actions.get_snapshot().values[3]==1,"Sound did not become monaural")
	if not await click("Options/Stereo/Interact"): return
	check(actions.get_snapshot().values[3]==0,"Sound did not return to stereo")
	if not await click("Options/CaptionOff/Interact"): return
	check(actions.get_snapshot().values[1]==1,"Captions did not turn off")
	if not await click("Options/CaptionOn/Interact"): return
	check(actions.get_snapshot().values[1]==0,"Captions did not turn on")
	if not await click("Options/Screen/Interact"): return
	check(runtime.display_menu.ui.opened and actions.get_snapshot().selection==6,"Display page did not open from Options")
	runtime.display_menu.ui.close_menu()
	check(not runtime.display_menu.ui.opened and actions.captures_input(),"Display Back did not restore Options")
	if not await click("Options/Controller/Interact"): return
	check(actions.get_snapshot().selection==9,"Controller page did not open")
	if not await click("Controller/TypeC/Interact"): return
	check(actions.get_snapshot().controller_type==2,"Type C not selected")
	if not await click("Controller/TypeB/Interact",JOY_BUTTON_B): return
	check(actions.get_snapshot().controller_type==1,"Focused Type B not selected by controller confirm")
	if not await click("Controller/Reverse/Interact"): return
	check(actions.get_snapshot().reverse==1,"First person reverse not selected")
	for frame in 3: await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.generated/options-actions-live")
	check(runtime.get_viewport().get_texture().get_image().save_png("res://.generated/options-actions-live/controller.png")==OK,"Cannot save Options image")
	if not await click("Controller/ControllerExit/Interact",JOY_BUTTON_A): return
	if not await click("Options/Exit/Interact"): return
	await wait_for(func():return not actions.get_snapshot().get("active",false),"Options did not apply and close")
	check(not actions.captures_input(),"Closed Options retained input")
