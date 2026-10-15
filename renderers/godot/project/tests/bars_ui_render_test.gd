extends SceneTree

var failures := 0
var viewport := SubViewport.new()

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

func run() -> void:
	var fixtures := preload("res://tests/goggles_ui_test.gd").new()
	var fixture := preload("res://tests/bars_ui_test.gd").new()
	var originals: Dictionary = fixtures.load_assets()
	viewport.size = Vector2i(640, 448)
	viewport.world_3d = World3D.new()
	root.add_child(viewport)
	viewport.add_child(Camera3D.new())
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.05, 0.05, 0.05)
	viewport.world_3d.environment = environment
	var fsr2 := "--fsr2" in OS.get_cmdline_user_args()
	if fsr2:
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
		viewport.scaling_3d_scale = 0.667
	var presenter := preload("res://bars_presenter.gd").new()
	viewport.add_child(presenter)
	var error := presenter.initialize({}, originals.root, originals.assets, originals.disc)
	check(error.is_empty(), "Cannot initialize status bars: " + error)
	if not error.is_empty():
		fixtures.free()
		fixture.free()
		viewport.free()
		quit(1)
		return
	presenter.fit_screen(Rect2(0, 0, 640, 448))
	presenter.state.session_id.resize(16)
	presenter.state.session_id.fill(7)
	var bytes: PackedByteArray = fixture.packet()
	check(presenter.state.apply(bytes, {"epoch": 3}).is_empty(), "Cannot apply status bars")
	presenter.present(3, true)
	var normal := await frame()
	var damage := normal.get_pixel(210, 36)
	check(damage.r > 0.7 and damage.g < 0.1, "Delayed damage segment not rendered red: " + str(damage))
	check(normal.get_pixel(90, 36).g > normal.get_pixel(90, 36).r, "Life gradient missing")
	check(normal.get_pixel(90, 60).b > normal.get_pixel(90, 60).r, "Oxygen gradient missing")
	check(normal.get_pixel(327, 84).b > 0.1, "Boss fill truncated to player maximum")
	var output := "res://.generated/bars-gpu-test"
	check(DirAccess.make_dir_recursive_absolute(output) == OK, "Cannot create bars evidence directory")
	check(normal.save_png(output.path_join("bars-%s.png" % ("fsr2" if fsr2 else "native"))) == OK, "Cannot save bars evidence")
	bytes.encode_u32(60, 1)
	presenter.state.apply(bytes, {"epoch": 3})
	presenter.present(3, true)
	var flashing := await frame()
	check(normal.get_region(Rect2i(40, 40, 50, 10)).get_data() != flashing.get_region(Rect2i(40, 40, 50, 10)).get_data(), "Damage did not tint LIFE label")
	presenter.state.apply(fixture.packet(0), {"epoch": 3})
	presenter.present(3, true)
	var hidden := await frame()
	check(hidden.get_pixel(210, 36).r < 0.1, "Bars survived native empty frame")
	fixture.free()
	fixtures.free()
	viewport.free()
	print("MGS_BARS_UI_RENDER_TEST failures=%d" % failures)
	quit(1 if failures else 0)
