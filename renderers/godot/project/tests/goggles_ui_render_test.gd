extends SceneTree

const Presenter = preload("res://goggles_presenter.gd")
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

func region(image: Image) -> PackedByteArray:
	return image.get_region(Rect2i(82, 84, 64, 12)).get_data()

func run() -> void:
	var fixture := preload("res://tests/goggles_ui_test.gd").new()
	var originals: Dictionary = fixture.load_assets()
	viewport.size = Vector2i(640, 448)
	viewport.world_3d = World3D.new()
	root.add_child(viewport)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.05, 0.05, 0.05)
	viewport.world_3d.environment = environment
	var fsr2 := "--fsr2" in OS.get_cmdline_user_args()
	if fsr2:
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
		viewport.scaling_3d_scale = 0.667
	var presenter := Presenter.new()
	viewport.add_child(presenter)
	var error := presenter.initialize({}, originals.root, originals.assets, originals.disc)
	check(error.is_empty(), "Cannot initialize goggles: " + error)
	if not error.is_empty():
		fixture.free()
		viewport.free()
		quit(1)
		return
	presenter.fit_screen(Rect2(0, 0, 640, 448))
	presenter.state.session_id.resize(16)
	presenter.state.session_id.fill(1)
	check(presenter.state.apply(fixture.packet(1, 3), {"epoch": 3}).is_empty(), "Cannot apply hidden SCAN")
	presenter.present(3, true)
	var hidden := await frame()
	check(presenter.state.apply(fixture.packet(), {"epoch": 3}).is_empty(), "Cannot apply visible SCAN")
	presenter.present(3, true)
	var night := await frame()
	check(region(night) != region(hidden), "Native SCAN blink did not affect pixels")
	var output := "res://.generated/goggles-gpu-test"
	check(DirAccess.make_dir_recursive_absolute(output) == OK, "Cannot create UI evidence folder")
	var suffix := "fsr2" if fsr2 else "native"
	check(night.save_png(output.path_join("night-" + suffix + ".png")) == OK, "Cannot save night UI evidence")
	var scan := presenter.ui.get_node("NightVision/Indicators/Scan") as Label
	scan.add_theme_color_override("font_color", Color.BLUE)
	var blue := await frame()
	check(region(blue) != region(night), "Godot Label color edit is not rendered")
	check(presenter.state.apply(fixture.packet(2), {"epoch": 3}).is_empty(), "Cannot apply thermal UI")
	presenter.present(3, true)
	var thermal := await frame()
	check(region(thermal) != region(night), "Thermal UI retains night colors")
	check(thermal.save_png(output.path_join("thermal-" + suffix + ".png")) == OK, "Cannot save thermal evidence")
	presenter.present(4, true)
	var retired := await frame()
	check(retired.get_pixel(90, 90).r < 0.1 and not presenter.visible, "UI persisted after native epoch change")
	fixture.free()
	viewport.free()
	print("MGS_GOGGLES_UI_RENDER_TEST failures=%d" % failures)
	quit(1 if failures else 0)
