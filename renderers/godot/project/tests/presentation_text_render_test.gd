extends SceneTree

var failures := 0
var viewport := SubViewport.new()
var text := preload("res://subtitles_text.gd").new()

func check(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)

func _initialize() -> void:
	run.call_deferred()

func channels() -> Vector3:
	for tick in 3:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var result := Vector3.ZERO
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			result = result.max(Vector3(pixel.r, pixel.g, pixel.b))
	return result

func run() -> void:
	viewport.size = Vector2i(128, 64)
	viewport.transparent_bg = true
	root.add_child(viewport)
	viewport.add_child(text)
	text.font_size = 48
	text.outline_size = 0
	text.presentation_font = preload("res://presentation_fonts.gd").dialogue_font()
	var source := PackedByteArray()
	source.resize(24)
	source.fill(255)
	var palette := PackedInt32Array()
	palette.resize(16)
	palette[7] = 0x03e0
	text.apply_native_state({"active":true, "visible":true, "position":Vector2(4, 4),
		"layout":{"size":Vector2i(8, 12), "palette":palette, "glyphs":[
			{"kind":1, "code":65, "color":1, "position":Vector2i.ZERO, "size":Vector2i(8, 12), "source":source}]}})
	var green := await channels()
	check(green.y > 0.9 and green.x < 0.01 and green.z < 0.01, "Sharp text lost native green palette")
	text.font_override = text.presentation_font
	text.font_color = Color.BLUE
	var blue := await channels()
	check(blue.z > 0.9 and blue.x < 0.01 and blue.y < 0.01, "Author font/color override lost precedence")
	print("MGS_PRESENTATION_TEXT_RENDER_TEST failures=%d" % failures)
	viewport.free()
	quit(1 if failures else 0)
