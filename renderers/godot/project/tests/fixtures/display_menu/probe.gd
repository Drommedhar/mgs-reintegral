extends Node3D

var failures := 0
var runtime: Node
var ui: Control
var display: Node

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _ready() -> void: run.call_deferred()

func wait_phase(phase: String) -> bool:
	var deadline := Time.get_ticks_msec() + 20000
	while display.phase != phase and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	check(display.phase == phase, "Display phase did not reach " + phase)
	return display.phase == phase

func key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	await get_tree().process_frame

func click(path: String) -> void:
	var button: Control = ui.get_node(path)
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	Input.parse_input_event(motion)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame

func save_image(name: String) -> void:
	for frame in 3: await RenderingServer.frame_post_draw
	var image: Image = runtime.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://.generated/display-menu-live")
	check(image.save_png("res://.generated/display-menu-live/"+name+".png")==OK,"Cannot save live menu image")

func preview() -> bool:
	var resolution: OptionButton = ui.get_node("Panel/Resolution")
	for index in resolution.item_count:
		if resolution.get_item_text(index)=="1280x720": resolution.select(index)
	ui.get_node("Panel/Widescreen").button_pressed = true
	await click("Panel/Preview")
	if not await wait_phase("preview"): return false
	check(display.applied["display.resolution"]=="1280x720" and display.applied["display.widescreen"], "Menu fields did not apply")
	check(resolution.get_item_text(resolution.selected)=="1280x720" and ui.get_node("Panel/Widescreen").button_pressed, "Menu shows stale applied values")
	check(runtime.display_menu.captured and ui.get_node("Panel/Revert").has_focus(), "Confirmation lost input ownership or safe focus")
	return true

func run() -> void:
	var api := get_tree().get_first_node_in_group("mgs_visual_api_v1")
	var provider: Node = api.get_settings_provider()
	display = provider.display
	runtime = display.get_parent()
	ui = runtime.display_menu.ui
	var deadline := Time.get_ticks_msec()+30000
	while (provider.snapshot.is_empty() or not display.supported or runtime.gpu.world_composites<10) and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
	check(not provider.snapshot.is_empty() and display.supported and runtime.gpu.world_composites>=10,"Display menu runtime did not become ready")
	if failures:
		done()
		return
	var original: Dictionary = display.applied.duplicate()
	await key(KEY_F10,true)
	await key(KEY_F10,false)
	check(runtime.display_menu.captured,"F10 did not open menu in native session")
	await key(KEY_UP,true)
	check(runtime.display_menu.buttons(0x1000)==0x40000000,"Menu leaked direction into native reply")
	if not await preview():
		done()
		return
	await save_image("preview")
	await click("Panel/Revert")
	if not await wait_phase("idle"):
		done()
		return
	check(display.applied == original, "Menu revert failed")
	if not await preview():
		done()
		return
	await click("Panel/Keep")
	if not await wait_phase("idle"):
		done()
		return
	check(provider.snapshot.saved == display.applied,"Menu Keep did not persist")
	await click("Panel/Close")
	check(not runtime.display_menu.captured and runtime.display_menu.buttons(0x1000)==0,"Close leaked held direction")
	await key(KEY_UP,false)
	check(runtime.display_menu.buttons(0)==0 and runtime.display_menu.buttons(0x1000)==0x1000,"Released keyboard did not resume")
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_RIGHT_STICK
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	check(runtime.display_menu.captured, "Controller shortcut failed in native session")
	await click("Panel/Close")
	await save_image("closed")
	print("MGS_DISPLAY_MENU_LIVE_STATE " + JSON.stringify({"frames":runtime.frame_number,"world":runtime.gpu.world_composites,"applied":display.applied}))
	done()

func done() -> void:
	print("MGS_DISPLAY_MENU_LIVE_TEST failures=%d"%failures)
	runtime.request_close()
