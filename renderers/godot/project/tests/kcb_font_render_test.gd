extends SceneTree

const Assets = preload("res://original_ui_assets.gd")
const TEXT := "Snake, do you read me?"
var failures := 0
var viewport := SubViewport.new()
var canvas := Control.new()

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func frame() -> Image:
	for _tick in 3:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func compare(image: Image, atlas: Image, glyphs: Dictionary, tint: Color) -> void:
	var expected := Image.create(280, 18, false, Image.FORMAT_RGBA8)
	expected.fill(Color(0.1, 0.2, 0.3))
	var cursor := 0
	for index in TEXT.length():
		var glyph: Dictionary = glyphs[str(TEXT.unicode_at(index))]
		var rect := Rect2i(glyph.rect[0], glyph.rect[1], glyph.rect[2], glyph.rect[3])
		for y in rect.size.y:
			for x in rect.size.x:
				var color := atlas.get_pixel(rect.position.x + x, rect.position.y + y)
				if color.a > 0: expected.set_pixel(cursor + x, y + int(glyph.offset_y), color * tint)
		cursor += int(glyph.advance)
	var differences := 0
	for y in 18:
		for x in 280:
			var actual := image.get_pixel((20 + x) * 2, (20 + y) * 2)
			var wanted := expected.get_pixel(x, y)
			if absf(actual.r - wanted.r) + absf(actual.g - wanted.g) + absf(actual.b - wanted.b) > 0.025: differences += 1
	check(differences == 0, "Godot subtitle pixels differ from imported native glyphs: %d" % differences)

func run() -> void:
	var arguments := OS.get_cmdline_user_args()
	var assets := resources(arguments)
	var font: FontFile = assets.font("mgs/ui/subtitle")
	check(font != null, "Cannot load original subtitle font: " + assets.error)
	if font == null:
		quit(1)
		return
	viewport.size = Vector2i(640, 448)
	viewport.world_3d = World3D.new()
	root.add_child(viewport)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	if "--fsr2" in arguments:
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
		viewport.scaling_3d_scale = 0.667
	viewport.add_child(canvas)
	canvas.scale = Vector2(2, 2)
	var background := ColorRect.new()
	background.color = Color(0.1, 0.2, 0.3)
	background.size = Vector2(320, 224)
	canvas.add_child(background)
	var label := Label.new()
	label.position = Vector2(20, 20)
	label.text = TEXT
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 12)
	canvas.add_child(label)
	var document: Dictionary = assets.document("mgs/ui/subtitle", "ui_font")
	var atlas := font.get_texture_image(0, Vector2i(12, 0), 0)
	var rendered := await frame()
	compare(rendered, atlas, document.glyphs, Color.WHITE)
	DirAccess.make_dir_recursive_absolute("res://.generated/kcb-font-test")
	var suffix := "-fixture" if assets.root.begins_with("res://.generated/") else ""
	if "--fsr2" in arguments: suffix += "-fsr2"
	check(rendered.save_png("res://.generated/kcb-font-test/subtitle%s.png" % suffix) == OK, "Cannot save font render proof")
	label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	compare(await frame(), atlas, document.glyphs, Color(0.5, 1.0, 0.5))
	viewport.free()
	print("MGS_KCB_FONT_RENDER_TEST failures=%d" % failures)
	quit(0 if failures == 0 else 1)

func resources(arguments: PackedStringArray) -> RefCounted:
	for directory in arguments:
		if directory.begins_with("--"): continue
		var catalog = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("catalog.json")))
		var assets := Assets.new()
		assets.configure(directory, catalog.assets, int(catalog.disc))
		return assets
	var fixture := preload("res://tests/kcb_font_test.gd").new()
	var assets: RefCounted = fixture.fixture_assets()
	check(fixture.failures == 0, "Cannot prepare synthetic GPU font fixture")
	fixture.free()
	return assets
