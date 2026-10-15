extends SceneTree

var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	create_timer(45).timeout.connect(quit.bind(1))
	run.call_deferred()

func capture(viewport: SubViewport) -> Image:
	for frame in 3:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func difference(a: Image, b: Image) -> float:
	var total := 0.0
	for y in a.get_height():
		for x in a.get_width():
			var first := a.get_pixel(x,y)
			var second := b.get_pixel(x,y)
			total += absf(first.r-second.r) + absf(first.g-second.g) + absf(first.b-second.b)
	return total / (a.get_width() * a.get_height())

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Snow render test needs a rendering device")
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960,540)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var scene: Node3D = load("res://examples/snow/preview.tscn").instantiate()
	viewport.add_child(scene)
	var snow: Node3D = scene.get_node("SnowVolume")
	snow.simulation_mode = 1
	snow.set_physics_process(false)
	snow.collision.prepare(1000000)
	snow.collision.sync()
	await physics_frame
	await physics_frame
	snow.advance(1.0/60)
	var first := await capture(viewport)
	for frame in 60: snow.advance(1.0/60)
	var moved := await capture(viewport)
	check(difference(first, moved) > 0.00005, "Snow particles did not render or move")
	snow.hide()
	var clear := await capture(viewport)
	check(difference(clear, moved) > 0.00005, "Snow has no visible contribution")
	snow.show()
	snow.flake_size *= 3
	snow.advance(0)
	var larger := await capture(viewport)
	check(difference(larger, clear) > difference(moved, clear) * 1.8, "Flake size did not change rendered coverage")
	var directory := OS.get_environment("MGS_SNOW_TEST_OUTPUT")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		moved.save_png(directory.path_join("snow-volume.png"))
		clear.save_png(directory.path_join("snow-without.png"))
		larger.save_png(directory.path_join("snow-large-flakes.png"))
	print("MGS_SNOW_RENDER_TEST failures=%d snow_difference=%.6f" % [failures,difference(moved,clear)])
	viewport.free()
	quit(1 if failures else 0)
