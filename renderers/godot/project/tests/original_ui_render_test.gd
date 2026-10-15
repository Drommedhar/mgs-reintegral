extends SceneTree

const Assets = preload("res://original_ui_assets.gd")
const Shape = preload("res://original_ui_shape.gd")
const Fixture = preload("res://tests/original_ui_test.gd")
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

func label(font: FontFile, text: String, position: Vector2) -> Label:
	var node := Label.new()
	node.position = position
	node.text = text
	node.add_theme_font_override("font", font)
	node.add_theme_font_size_override("font_size", 8)
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.add_child(node)
	return node

func run() -> void:
	var fixture := Fixture.new()
	var catalog: Dictionary = fixture.fixture()
	check(fixture.failures == 0, "UI fixture failed")
	fixture.free()
	var assets := Assets.new()
	assets.configure(Fixture.ROOT, catalog)
	viewport.size = Vector2i(640, 448)
	viewport.world_3d = World3D.new()
	root.add_child(viewport)
	viewport.world_3d.environment = Environment.new()
	viewport.world_3d.environment.background_mode = Environment.BG_COLOR
	viewport.world_3d.environment.background_color = Color.BLACK
	if "--fsr2" in OS.get_cmdline_user_args():
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
		viewport.scaling_3d_scale = 0.667
	viewport.add_child(canvas)
	canvas.scale = Vector2(2, 2)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	var shape := Shape.new()
	shape.source_id = Fixture.LAYOUT
	shape.position = Vector2(30, 30)
	canvas.add_child(shape)
	check(shape.bind(assets).is_empty(), "Cannot bind UI polygon")
	var font := assets.font(Fixture.FONT)
	check(font != null, "Cannot load UI font")
	if font == null:
		quit(1)
		return
	var text := label(font, "AIA", Vector2(50, 50))
	var rendered := await frame()
	check(rendered.get_pixel(66, 66).r > 0.9 and rendered.get_pixel(66, 66).g < 0.4, "Original UI vector is missing or has wrong tint")
	check(rendered.get_pixel(102, 102).r > 0.95 and rendered.get_pixel(98, 102).r < 0.01, "UI font position/scaling/coverage is incorrect")
	check(rendered.get_pixel(112, 102).r < 0.01 and rendered.get_pixel(114, 102).r > 0.95, "Narrow glyph offset changed")
	check(rendered.get_pixel(102, 110).r < 0.01, "UI glyph extends below original five-pixel height")
	shape.self_modulate = Color(0, 1, 0)
	text.add_theme_color_override("font_color", Color.GREEN)
	rendered = await frame()
	check(rendered.get_pixel(102, 102).g > 0.95 and rendered.get_pixel(102, 102).r < 0.01, "Label font color edit ignored")
	text.visible = false
	rendered = await frame()
	check(rendered.get_pixel(66, 66).r < 0.01 and rendered.get_pixel(66, 66).g > 0.2, "CanvasItem tint edit ignored")
	check(rendered.get_pixel(102, 102).r < 0.01, "Label visibility edit ignored")
	shape.free()
	text.free()
	var arguments := OS.get_cmdline_user_args()
	for argument in arguments:
		if not argument.begins_with("--"): await disc_preview(argument)
	viewport.free()
	print("MGS_ORIGINAL_UI_RENDER_TEST failures=%d" % failures)
	quit(0 if failures == 0 else 1)

func disc_preview(directory: String) -> void:
	var catalog = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("catalog.json")))
	var assets := Assets.new()
	assets.configure(directory, catalog.assets)
	var prefix := "mgs/integral-j/disc%d/stage/init/" % catalog.disc
	for identity in ["8504.s", "8505.s", "8506.s"]:
		var layout: Dictionary = assets.layout(prefix + identity)
		check(not layout.is_empty(), "Disc layout missing: " + assets.error)
		if layout.is_empty(): return
		for index in layout.draw_order:
			var shape := Shape.new()
			shape.source_id = prefix + identity
			shape.shape_index = int(index)
			canvas.add_child(shape)
			check(shape.bind(assets).is_empty(), "Cannot bind disc vector")
	var large := assets.font(prefix + "5d43.r")
	var small := assets.font(prefix + "c70e.r")
	check(large != null and small != null, "Disc fonts missing")
	if large == null or small == null: return
	label(large, "MODE-B", Vector2(41, 42))
	label(large, "SCAN", Vector2(137, 42))
	label(small, "00000\n08192\n16384", Vector2(40, 56))
	label(small, "04 03 02 01 00 01 02 03 04", Vector2(80, 148))
	var result := await frame()
	check(result.save_png("res://.generated/original-ui-test/disc-preview.png") == OK, "Cannot save disc UI preview")
