extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)

func _initialize() -> void:
	OS.set_environment("MGS_GODOT_PIXEL_FONTS", "1")
	run.call_deferred()

func run() -> void:
	var directory := ProjectSettings.globalize_path("res://../../../.local/godot-content")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("catalog.json")))
	var resources := preload("res://original_ui_assets.gd").new()
	resources.configure(directory, catalog.assets, 1)
	var builder := preload("res://codec_scene.gd").new()
	var ui: Control = builder.create(resources)
	root.add_child(ui)
	check(ui.bind_originals(resources).is_empty(), "Original Codec binding failed")
	await process_frame
	var hint: Label = ui.get_node("Incoming/Hint")
	var width := hint.get_theme_font("font").get_string_size(hint.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	check(hint.global_position.x + (hint.size.x - width) / 2 == 128, "PUSH SELECT is not at native x128")
	check(hint.global_position.y == 63, "PUSH SELECT is not at native y63")
	for path in ["Panel/Console", "Panel/Console/Foreground"]:
		var memory: Label = ui.get_node(path + "/Memory")
		check(memory.global_position == Vector2(134,111) and memory.get_theme_font("font").get_ascent(8) == 6, "MEMORY uses wrong origin or font family")
		var ptt: Label = ui.get_node(path + "/PTT")
		check(ptt.global_position == Vector2(144,32) and ptt.text == "PTT", "PTT uses wrong origin or literal spaces")
		var font: Font = ptt.get_theme_font("font")
		check(font.get_string_size("PT", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x - font.get_string_size("T", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x == 12, "PTT spacing differs from native #3 advance")
	ui.preview_mode = 2
	ui.update_preview()
	var row: Control = ui.get_node("Panel/Contacts/Contact0")
	check(row.get_node("Frequency").global_position == Vector2(26,136), "Contact frequency integer origin differs")
	check(row.get_node("FrequencyDot").global_position == Vector2(44,139), "Contact decimal origin differs")
	check(row.get_node("FrequencyFraction").global_position == Vector2(46,136), "Contact fractional origin differs")
	check(row.get_node("Frequency").text == "140" and row.get_node("FrequencyFraction").text == "85", "Contact frequency digits differ")
	ui.free()
	await process_frame
	print("MGS_CODEC_LAYOUT_TEST failures=%d" % failures)
	quit(1 if failures else 0)
