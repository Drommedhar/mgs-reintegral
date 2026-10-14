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
	print("MGS_TITLE_CLICK %s id=%d input=%s values=%s"%[path,finished_id,"controller" if joy_button>=0 else "mouse",JSON.stringify(actions.get_snapshot().get("values",[]))])
	return result.is_empty()

func run() -> void:
	var api := get_tree().get_first_node_in_group("mgs_visual_api_v1")
	if api.has_meta("title_probe_started"): return
	api.set_meta("title_probe_started",true)
	reparent(get_tree().root)
	actions=api.get_title_actions()
	runtime=actions.get_parent()
	ui=runtime.title.ui
	actions.action_finished.connect(func(id,error):finished_id=id;result=error)
	if await wait_for(func():return actions.get_snapshot().get("active",false) and actions.get_snapshot().get("revision",0)>0,"Title did not accept input"):
		if actions.get_snapshot().get("mode",0) in [0,1]: await click("Title/SkipIntro/Interact")
		if await wait_for(func():return actions.get_snapshot().get("mode",0)==6 and actions.get_snapshot().get("revision",0)>0,"Press Start did not finish opening"): await exercise()
	print("MGS_TITLE_ACTIONS_LIVE failures=%d frames=%d"%[failures,runtime.frame_number])
	runtime.request_close()

func exercise() -> void:
	check(actions.captures_input(),"Title does not own input")
	if not await click("Title/PressStart/Interact"): return
	await wait_for(func():return actions.get_snapshot().get("mode",0)==7 and actions.get_snapshot().get("revision",0)>0,"Main menu not ready")
	if not await options_round_trip(): return
	if not await click("Menu/NewGame/Interact",JOY_BUTTON_B): return
	check(actions.get_snapshot().mode==21,"Difficulty did not open")
	check(actions.request("select",4)==0,"Locked Extreme accepted")
	# Cancel returns through the original menu flow without launching a game.
	var before := finished_id
	var event := InputEventAction.new()
	event.action="ui_up"
	event.pressed=true
	Input.parse_input_event(event)
	if not await wait_for(func():return finished_id>before,"Difficulty selection not acknowledged"): return
	check(actions.get_snapshot().difficulty==1,"Easy not selected")
	if not await click("Difficulty/Level1/Interact",JOY_BUTTON_A): return
	check(actions.get_snapshot().mode==7,"Difficulty Back did not return to menu")
	if not await click("Menu/NewGame/Interact",JOY_BUTTON_A): return
	await wait_for(func():return actions.get_snapshot().get("mode",0)==6 and actions.get_snapshot().get("revision",0)>0,"Main Back did not return to Press Start")
	if not await click("Title/PressStart/Interact",JOY_BUTTON_START): return
	await wait_for(func():return actions.get_snapshot().get("mode",0)==7 and actions.get_snapshot().get("revision",0)>0,"Main did not reopen")
	if not await click("Menu/NewGame/Interact"): return
	for frame in 3: await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.generated/title-actions-live")
	check(runtime.get_viewport().get_texture().get_image().save_png("res://.generated/title-actions-live/difficulty.png")==OK,"Cannot save title image")
	if not await click("Difficulty/Level2/Interact",JOY_BUTTON_B): return
	if not await wait_for(func():return not actions.get_snapshot().get("active",false) or actions.get_snapshot().get("mode",0) in [18,19],"Native new game did not advance"): return
	if actions.get_snapshot().get("mode",0) in [18,19]:
		if not await click("StorageWarning/Continue/Interact"): return
	await wait_for(func():return not actions.get_snapshot().get("active",false),"Title did not close")
	check(not actions.captures_input(),"Closed title retained input")
	if not await wait_for(func():return runtime.native_context.current.get("stage","")=="d00a" and runtime.scene_view.scene_stage=="d00a" and runtime.scene_view.current_instances>0,"New game did not load the docks"): return
	var loaded_tick: int = runtime.native_context.current.actor_loop_tick
	if not await wait_for(func():return runtime.native_context.current.actor_loop_tick>=loaded_tick+90,"Docks native clock stopped"): return
	for frame in 3: await RenderingServer.frame_post_draw
	var image: Image = runtime.get_viewport().get_texture().get_image()
	var luminance := 0.0
	for y in range(0,image.get_height(),16):
		for x in range(0,image.get_width(),16): luminance=maxf(luminance,image.get_pixel(x,y).get_luminance())
	check(luminance>0.01,"Docks rendered only black after opening fade")
	check(image.save_png("res://.generated/title-actions-live/new-game.png")==OK,"Cannot save new-game image")
	print("MGS_TITLE_NEW_GAME stage=%s instances=%d epoch=%d"%[runtime.scene_view.scene_stage,runtime.scene_view.current_instances,runtime.native_context.current.epoch])

func select_main(target: int) -> bool:
	var id: int = actions.request("select",target)
	check(id>0,"Main menu selection rejected")
	if not id or not await wait_for(func():return finished_id==id,"Main selection not acknowledged"): return false
	check(result.is_empty() and actions.get_snapshot().selection==target,"Main selection not applied")
	return failures==0

func options_round_trip() -> bool:
	var generation: int = actions.get_snapshot().generation
	if not await select_main(2): return false
	if not await click("Menu/Options/Interact"): return false
	var options: Node = runtime.options_actions
	if not await wait_for(func():return options.get_snapshot().get("active",false) and options.get_snapshot().get("selection",0)==1,"Options callback did not open"): return false
	check(not actions.captures_input() and options.captures_input(),"Title did not transfer input to Options")
	await mouse_click(runtime.options.ui.get_node("Options/Exit/Interact"))
	if not await wait_for(func():return actions.get_snapshot().get("mode",0)==7 and actions.get_snapshot().get("revision",0)>0 and actions.get_snapshot().get("generation",0)>generation,"Options did not return to a new title actor"): return false
	check(not options.captures_input() and actions.captures_input(),"Options did not return input to Title")
	print("MGS_TITLE_OPTIONS_ROUND_TRIP generation=%d"%actions.get_snapshot().generation)
	return await select_main(0)
