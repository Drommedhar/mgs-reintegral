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
	print("MGS_DISPLAY_OPTIONS_LIVE failures=%d frames=%d"%[failures,runtime.frame_number])
	runtime.request_close()

func exercise() -> void:
	var display_ui: Control = runtime.display_menu.ui
	check(display_ui.get_node_or_null("Entry")==null,"Global Display entry remains")
	check(not display_ui.get_node("Panel/Close").is_visible_in_tree(),"Back visible outside Display")
	check(ui.get_node("Options/Screen/Interact").text=="DISPLAY","Display not registered in Options")
	await screenshot("options")
	if not await click("Options/Screen/Interact"): return
	check(actions.get_snapshot().selection==6,"Options did not retain Display selection")
	check(display_ui.opened and not actions.captures_input(),"Display did not take input")
	check(display_ui.get_node("Panel/Close").is_visible_in_tree(),"Display lacks Back")
	await screenshot("display")
	for down in [true,false]:
		var event := InputEventJoypadButton.new()
		event.button_index=JOY_BUTTON_A
		event.pressed=down
		Input.parse_input_event(event)
		await get_tree().process_frame
	check(not display_ui.opened and actions.captures_input(),"Controller Back did not return to Options")
	check(ui.get_node("Options/Screen/Interact").has_focus(),"Back lost Display focus")
	check(not display_ui.get_node("Panel/Close").is_visible_in_tree(),"Back remained outside Display")
	if not await click("Options/Screen/Interact",JOY_BUTTON_B): return
	check(display_ui.opened,"Controller did not reopen Display")
	await mouse_click(display_ui.get_node("Panel/Close"))
	check(not display_ui.opened and actions.captures_input(),"Mouse Back failed")
	await screenshot("returned")

func screenshot(name: String) -> void:
	for frame in 3: await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.generated/display-options-live")
	check(runtime.get_viewport().get_texture().get_image().save_png("res://.generated/display-options-live/"+name+".png")==OK,"Cannot save Options image")
