extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event

func pad(button: JoyButton, device: int = 0) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.device = device
	event.pressed = true
	return event

func check_title(event: InputEvent, action: int, target: int, mode: int = 21) -> void:
	var provider := preload("res://title_actions.gd").new()
	provider.supported = true
	var ui := preload("res://title_ui.gd").new()
	var button := preload("res://title_button.gd").new()
	button.native_page = mode
	button.native_target = 2 if mode == 21 else 0
	ui.add_child(button)
	root.add_child(ui)
	ui.connect_provider(provider)
	provider.present({"active":true,"epoch":1,"generation":1,"revision":1,"mode":mode,
		"selection":0,"difficulty":2,"storage_choice":0,"extreme":false})
	button.grab_focus()
	ui._input(event)
	var actual: Array = []
	if not provider._queued.is_empty():
		actual = [provider._queued.decode_u32(20), provider._queued.decode_u32(24)]
	var expected: Array = [action,target] if action else []
	if actual != expected:
		failures += 1
		push_error("Menu input %s (mode %d): expected %s, got %s" % [event.as_text(),mode,expected,actual])
	ui.free()
	provider.free()

func run() -> void:
	check_title(key(KEY_D), 2, 2)
	check_title(key(KEY_X), 3, 0)
	check_title(pad(JOY_BUTTON_B), 2, 2)
	check_title(pad(JOY_BUTTON_A), 3, 0)
	check_title(pad(JOY_BUTTON_B, 1), 2, 2)
	check_title(pad(JOY_BUTTON_A, 1), 3, 0)
	check_title(key(KEY_DOWN), 1, 3)
	check_title(pad(JOY_BUTTON_DPAD_UP), 1, 1)
	check_title(key(KEY_ENTER), 2, 0, 6)
	check_title(pad(JOY_BUTTON_START), 2, 0, 6)
	check_title(pad(JOY_BUTTON_START, 1), 2, 0, 6)
	check_title(key(KEY_ENTER), 2, 0, 7)
	check_title(pad(JOY_BUTTON_START), 2, 0, 7)
	check_title(key(KEY_ENTER), 0, 0)
	check_title(pad(JOY_BUTTON_START), 0, 0)
	check_title(pad(JOY_BUTTON_B), 0, 0, 6)
	check_title(key(KEY_SPACE), 0, 0)
	var remapped := key(KEY_D)
	remapped.keycode = KEY_A
	check_title(remapped, 2, 2)
	remapped = key(KEY_X)
	remapped.keycode = KEY_Q
	check_title(remapped, 3, 0)
	print("MGS_MENU_INPUT_TEST failures=%d" % failures)
	quit(1 if failures else 0)
