extends SceneTree

const Text = preload("res://subtitles_text.gd")
var failures := 0
var viewport := SubViewport.new()

func _initialize() -> void:
	run.call_deferred()

func capture() -> Image:
	for tick in 3:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func glyph_source(image: Image, rect: Rect2i) -> PackedByteArray:
	var source := PackedByteArray()
	source.resize(rect.size.x * 3)
	for y in rect.size.y:
		for x in rect.size.x:
			var pixel := image.get_pixelv(rect.position + Vector2i(x, y))
			var value := 3 if pixel.a > 0.5 and pixel.r > 0.2 else 0
			var index := y * rect.size.x + x
			source[index / 4] |= value << (6 - (index % 4) * 2)
	return source

func visible_bounds(image: Image) -> Rect2i:
	var bounds := Rect2i()
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a < 0.1: continue
			var pixel := Rect2i(x, y, 1, 1)
			bounds = bounds.merge(pixel) if bounds.has_area() else pixel
	return bounds

func run() -> void:
	var directory := ProjectSettings.globalize_path("res://../../../.local/godot-content/init/ui")
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("ca68.r.json")))
	var atlas := Image.load_from_file(directory.path_join("ca68.r.png"))
	var characters := "They're demanding that the government turn over the remains of Big Boss."
	viewport.size = Vector2i(1024, 512)
	viewport.transparent_bg = true
	root.add_child(viewport)
	var text := Text.new()
	text.scale = Vector2(8, 8)
	text.outline_size = 0
	viewport.add_child(text)
	var glyphs: Array[Dictionary] = []
	var unique := ""
	for character in characters:
		if character == " " or character in unique: continue
		unique += character
		var code := character.unicode_at(0)
		var glyph: Dictionary = document.glyphs[str(code)]
		var rect := Rect2i(glyph.rect[0], glyph.rect[1], glyph.rect[2], glyph.rect[3])
		var index := glyphs.size()
		glyphs.append({"kind":1, "code":code, "color":0, "size":rect.size,
			"position":Vector2i((index % 8) * 16, (index / 8) * 20 + glyph.offset_y),
			"source":glyph_source(atlas, rect)})
	text.apply_native_state({"active":true, "visible":true, "position":Vector2.ZERO,
		"layout":{"size":Vector2i(128,64), "palette":PackedInt32Array([0,0,0,32767]), "glyphs":glyphs}})
	var original := await capture()
	text.bind_presentation_font(preload("res://presentation_fonts.gd").dialogue_font())
	var sharp := await capture()
	if OS.has_environment("MGS_TEXT_CAPTURE"):
		original.save_png(OS.get_environment("MGS_TEXT_CAPTURE") + "-original.png")
		sharp.save_png(OS.get_environment("MGS_TEXT_CAPTURE") + "-sharp.png")
	for index in glyphs.size():
		var cell := Rect2i((index % 8) * 128, (index / 8) * 160, 128, 160)
		var before := visible_bounds(original.get_region(cell))
		var after := visible_bounds(sharp.get_region(cell))
		if (maxi(absi(before.position.x - after.position.x), absi(before.position.y - after.position.y)) > 8 or
			maxi(absi(before.end.x - after.end.x), absi(before.end.y - after.end.y)) > 8):
			failures += 1
			push_error("Glyph %s differs from original ink bounds: %s -> %s" % [unique[index], before, after])
	viewport.free()
	print("MGS_DIALOGUE_ALIGNMENT_RENDER_TEST failures=", failures)
	quit(1 if failures else 0)
