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
	var directory := ProjectSettings.globalize_path("res://../../../.local/godot-content")
	var catalog = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("catalog.json")))
	var fixture := preload("res://tests/radar_ui_test.gd").new()
	viewport.size = Vector2i(640,448)
	viewport.world_3d = World3D.new()
	root.add_child(viewport)
	viewport.add_child(Camera3D.new())
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.1,0.1,0.1)
	viewport.world_3d.environment = environment
	var fsr2 := "--fsr2" in OS.get_cmdline_user_args()
	if fsr2:
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
		viewport.scaling_3d_scale = 0.667
	var presenter := preload("res://radar_presenter.gd").new()
	viewport.add_child(presenter)
	var error := presenter.initialize({}, directory, catalog.assets, int(catalog.disc))
	check(error.is_empty(), "Cannot initialize radar: " + error)
	if not error.is_empty():
		fixture.free()
		viewport.free()
		quit(1)
		return
	presenter.fit_screen(Rect2(0,0,640,448))
	presenter.state.session_id.resize(16)
	presenter.state.session_id.fill(7)
	var evidence := Image.create_empty(71 * 4, 54 * 4 * 6, false, Image.FORMAT_RGBA8)
	for mode in [0,1,2,3,5,0]:
		var data: PackedByteArray = fixture.packet(mode)
		data.encode_s32(96, 1 if mode in [1,2,3] else 0)
		if mode == 0 and evidence.get_meta("rows",0) == 5: data.encode_s32(76,69)
		check(presenter.state.apply(data, {"epoch":3}).is_empty(), "Cannot apply radar mode")
		presenter.present(3, true)
		var rendered := await frame()
		var color := rendered.get_pixel(472,130)
		if mode == 3 or mode == 5: check(color.r > color.g + 0.25, "Red radar background missing: " + str(color))
		if mode == 1: check(color.g > color.r + 0.15, "Jamming background missing")
		if mode == 0 and data.decode_s32(76) == 0:
			var contact := rendered.get_pixel(562,84)
			check(contact.r > 0.9 and contact.g > 0.3 and contact.b < 0.01, "Native contact missing: " + str(contact))
		var crop := rendered.get_region(Rect2i(468,30,142,108))
		crop.convert(Image.FORMAT_RGBA8)
		crop.resize(284,216,Image.INTERPOLATE_NEAREST)
		var row: int = evidence.get_meta("rows",0)
		evidence.blit_rect(crop,Rect2i(0,0,284,216),Vector2i(0,row * 216))
		evidence.set_meta("rows",row + 1)
	var output := "res://.generated/radar-gpu-test"
	check(DirAccess.make_dir_recursive_absolute(output) == OK, "Cannot create radar evidence directory")
	check(evidence.save_png(output.path_join("radar-%s.png" % ("fsr2" if fsr2 else "native"))) == OK, "Cannot save radar evidence")
	presenter.state.apply(fixture.packet(0,0), {"epoch":3})
	presenter.present(3,true)
	var hidden := await frame()
	check(hidden.get_pixel(562,84).r < 0.2, "Radar survived hidden frame")
	fixture.free()
	viewport.free()
	print("MGS_RADAR_RENDER_TEST failures=%d" % failures)
	quit(1 if failures else 0)
