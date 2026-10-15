extends SceneTree

const DIRECTORY := "res://.generated/subtitles-native-fixtures"
var failures := 0
var viewport := SubViewport.new()
var text := preload("res://subtitles_text.gd").new()

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

func compare(image: Image, pixels: PackedByteArray, layout: Dictionary, outline: bool) -> void:
	var differences := 0
	var extent: Vector2i = layout.size
	var palette: PackedInt32Array = layout.palette
	check(pixels.size() == extent.x * extent.y / 2, "Native font backing size differs")
	for y in extent.y:
		for x in extent.x:
			var index := y * extent.x + x
			var color_index := (pixels[index / 2] >> ((index & 1) * 4)) & 15
			var color := text.GlyphFont.palette_color(palette[color_index])
			if color.a == 0:
				color = Color(0.1, 0.2, 0.3)
				if outline:
					for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
						var point: Vector2i = Vector2i(x, y) + offset
						if point.x < 0 or point.x >= extent.x or point.y < 0 or point.y >= extent.y: continue
						var neighbor: int = point.y * extent.x + point.x
						if palette[(pixels[neighbor / 2] >> ((neighbor & 1) * 4)) & 15] != 0: color = Color.BLACK
			var actual := image.get_pixel((20 + x) * 2, (20 + y) * 2)
			if absf(actual.r - color.r) + absf(actual.g - color.g) + absf(actual.b - color.b) > 0.025: differences += 1
	check(differences == 0, "Native formatted subtitle pixels differ: %d, outline=%s" % [differences, outline])

func run() -> void:
	var files := Array(DirAccess.get_files_at(DIRECTORY)).filter(func(file): return file.ends_with(".bin"))
	check(files.size() == 22, "Build and run mgs_text_layout_test with the fixture directory before this test")
	if files.size() != 22:
		quit(1)
		return
	files.sort()
	viewport.size = Vector2i(640, 448)
	viewport.world_3d = World3D.new()
	root.add_child(viewport)
	viewport.add_child(Camera3D.new())
	var fsr2 := "--fsr2" in OS.get_cmdline_user_args()
	if fsr2:
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
		viewport.scaling_3d_scale = 0.667
	var canvas := Control.new()
	canvas.scale = Vector2(2, 2)
	viewport.add_child(canvas)
	var background := ColorRect.new()
	background.size = Vector2(320, 224)
	background.color = Color(0.1, 0.2, 0.3)
	canvas.add_child(background)
	text.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.add_child(text)
	var state := preload("res://subtitles_state.gd").new()
	state.session_id.resize(16)
	state.session_id.fill(7)
	for file in files:
		var bytes := FileAccess.get_file_as_bytes(DIRECTORY.path_join(file))
		var error: String = state.apply(bytes, {"epoch": 3})
		check(error.is_empty(), "Native layout rejected for " + file + ": " + error)
		if not error.is_empty(): continue
		text.apply_native_state(state.present(3))
		var pixels := FileAccess.get_file_as_bytes(DIRECTORY.path_join(file.get_basename() + ".pixels"))
		for outline in [false, true]:
			text.outline_size = 1 if outline else 0
			var image := await frame()
			compare(image, pixels, state.current.layout, outline)
			if file == "case007.bin" and outline:
				check(image.save_png(DIRECTORY.path_join("render-%s.png" % ("fsr2" if fsr2 else "native"))) == OK, "Cannot save subtitle render evidence")
		print("SUBTITLE_PARITY ", file)
	viewport.free()
	print("MGS_SUBTITLES_RENDER_TEST failures=%d" % failures)
	quit(1 if failures else 0)
