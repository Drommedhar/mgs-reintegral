extends SceneTree

const Assets = preload("res://original_ui_assets.gd")
const Fonts = preload("res://presentation_fonts.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var directory := ProjectSettings.globalize_path("res://../../../.local/godot-content")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("catalog.json")))
	var original := Assets.new()
	var sharp := Assets.new()
	original.configure(directory, catalog.assets, 1)
	sharp.configure(directory, catalog.assets, 1)
	for identity in ["mgs/ui/menu_small", "mgs/ui/menu_large"]:
		OS.set_environment("MGS_GODOT_PIXEL_FONTS", "1")
		var before: FontFile = original.font(identity)
		OS.set_environment("MGS_GODOT_PIXEL_FONTS", "0")
		var after: FontFile = sharp.font(identity)
		check(before.get_ascent(8) == after.get_ascent(8) and before.get_descent(8) == after.get_descent(8), "Native baseline changed")
		for code in range(32, 127):
			check(before.get_glyph_advance(0, 8, code) == after.get_glyph_advance(0, 8, code), "Native advance changed: %d" % code)
			check(before.get_glyph_offset(0, Vector2i(8, 0), code) == after.get_glyph_offset(0, Vector2i(8, 0), code), "Native glyph position changed")
			check(before.get_glyph_size(0, Vector2i(8, 0), code) == after.get_glyph_size(0, Vector2i(8, 0), code), "Native glyph bounds changed")
		var before_image := before.get_texture_image(0, Vector2i(8, 0), 0)
		var after_image := after.get_texture_image(0, Vector2i(8, 0), 0)
		check(after_image.get_size() == before_image.get_size() * 8, "High-resolution glyph coverage missing")
		var antialiased := false
		var bytes := after_image.get_data()
		for index in range(3, bytes.size(), 4):
			var alpha := bytes[index]
			if alpha > 0 and alpha < 255: antialiased = true
		check(antialiased, "Smoothed glyph coverage missing")
	var dialogue: FontFile = Fonts.dialogue_font()
	check(dialogue != null and dialogue.multichannel_signed_distance_field and dialogue.has_char(83), "Scalable dialogue font missing")
	var ui: Control = preload("res://subtitles_scene.gd").new().create(sharp)
	check(ui.bind_originals(sharp).is_empty(), "Subtitle binding failed")
	var text: Control = ui.get_node("Text")
	check(text.presentation_font == dialogue, "Default font not bound to native-layout text")
	var custom := FontFile.new()
	text.font_override = custom
	ui.bind_originals(sharp)
	check(text.font_override == custom, "Author font override replaced")
	ui.detach_originals()
	check(text.presentation_font == null and text.font_override == custom, "Runtime font leaked into authoring save")
	OS.set_environment("MGS_GODOT_PIXEL_FONTS", "1")
	ui.bind_originals(original)
	check(text.presentation_font == null, "Pixel-font option ignored")
	ui.free()
	OS.unset_environment("MGS_GODOT_PIXEL_FONTS")
	print("MGS_PRESENTATION_FONTS_TEST failures=%d" % failures)
	quit(1 if failures else 0)
