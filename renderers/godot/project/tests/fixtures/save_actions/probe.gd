extends Node3D

var failures := 0
var actions: Node
var runtime: Node
var ui: Control
var mode := ""
var result := ""
var finished_id := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _ready() -> void: run.call_deferred()

func wait_for(predicate: Callable, description: String) -> bool:
	var deadline := Time.get_ticks_msec()+45000
	while not predicate.call() and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
	var ok: bool = predicate.call()
	check(ok,description+": "+JSON.stringify(actions.get_snapshot()))
	return ok

func wait_mode(value: int) -> bool:
	return await wait_for(func():return actions.get_snapshot().get("active",false) and actions.get_snapshot().get("state",-1)==value and not actions.is_pending(),"Save state did not reach %d"%value)

func click(path: String) -> bool:
	var button: Button = ui.get_node(path)
	check(button.is_visible_in_tree() and not button.disabled,"Button unavailable: "+path)
	if failures: return false
	var before := finished_id
	if mode=="new": await controller_press(button)
	else: await mouse_click(button)
	if not await wait_for(func():return finished_id>before,"No native action acknowledgement for "+path): return false
	check(result.is_empty(),"Native action rejected: "+result)
	print("MGS_SAVE_ACTION_CLICK "+path+" id="+str(finished_id)+" input="+("controller" if mode=="new" else "mouse"))
	return result.is_empty()

func controller_press(button: Button) -> void:
	button.grab_focus()
	for down in [true,false]:
		var event := InputEventJoypadButton.new()
		event.button_index=JOY_BUTTON_B
		event.pressed=down
		Input.parse_input_event(event)
		await get_tree().process_frame

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

func run() -> void:
	var api := get_tree().get_first_node_in_group("mgs_visual_api_v1")
	if api.has_meta("save_probe_started"): return
	api.set_meta("save_probe_started",true)
	reparent(get_tree().root)
	actions=api.get_save_actions()
	runtime=actions.get_parent()
	ui=runtime.save_load.ui
	mode=OS.get_environment("MGS_SAVE_TEST_MODE")
	actions.action_finished.connect(func(id,error):finished_id=id;result=error)
	if not await wait_mode(0):
		done()
		return
	check(actions.captures_input(),"Native save UI did not capture input")
	if mode=="new":
		if not await click("NewSave/Activate"):
			done()
			return
	else:
		ui._move_cursor(-30)
		if not await click("SaveList/Save0/Activate"):
			done()
			return
		if mode=="overwrite":
			if not await wait_mode(2) or not await click("Dialog/Cancel") or not await wait_mode(0):
				done()
				return
			check(ui.get_node("SaveList/Save0/Location").text!="","Cancelled overwrite lost catalog")
			if not await click("SaveList/Save0/Activate") or not await wait_mode(2):
				done()
				return
			check(ui.get_node("Dialog/Cancel").has_focus(),"Native overwrite did not default to Cancel")
			if not await click("Dialog/Confirm"):
				done()
				return
	if not await wait_mode(4):
		done()
		return
	check(actions.get_snapshot().message in [1,6],"Native file operation failed")
	for frame in 3: await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.generated/save-actions-live")
	check(runtime.get_viewport().get_texture().get_image().save_png("res://.generated/save-actions-live/"+mode+".png")==OK,"Cannot save UI image")
	if await click("Dialog/Continue"):
		await wait_for(func():return not actions.get_snapshot().get("active",false),"Save UI did not close")
		check(not actions.captures_input(),"Closed native UI retained capture")
		if mode=="load":
			await wait_for(func():return runtime.native_context.current.get("stage","")=="s13a" and runtime.gpu.world_composites>10,"Loaded save did not restore world")
	done()

func done() -> void:
	print("MGS_SAVE_ACTIONS_LIVE mode=%s failures=%d frames=%d"%[mode,failures,runtime.frame_number])
	runtime.request_close()
