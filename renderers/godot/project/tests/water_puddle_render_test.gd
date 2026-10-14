extends SceneTree

var failures := 0
var viewport := SubViewport.new()
var camera := Camera3D.new()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	create_timer(45).timeout.connect(quit.bind(1))
	run.call_deferred()

func render() -> Image:
	for _frame in 4:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func difference(first: Image, second: Image) -> float:
	var total := 0.0
	for y in first.get_height():
		for x in first.get_width():
			var delta := first.get_pixel(x, y) - second.get_pixel(x, y)
			total += absf(delta.r) + absf(delta.g) + absf(delta.b)
	return total / (first.get_width() * first.get_height())

func run() -> void:
	viewport.size = Vector2i(320, 240)
	viewport.own_world_3d = true
	root.add_child(viewport)
	viewport.add_child(camera)
	camera.position = Vector3(0, 3, 4)
	camera.look_at(Vector3.ZERO)
	camera.environment = Environment.new()
	camera.environment.background_mode = Environment.BG_COLOR
	camera.environment.background_color = Color.BLACK
	camera.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	camera.environment.ambient_light_color = Color.WHITE
	camera.environment.ambient_light_energy = 0.8
	var light := DirectionalLight3D.new()
	light.rotation_degrees.x = -60
	viewport.add_child(light)
	var puddle: Node3D = load("res://addons/mgs_water/puddle.tscn").instantiate()
	viewport.add_child(puddle)
	puddle.set_process(false)
	var material: ShaderMaterial = puddle.get_node("Surface").material_override
	material.set_shader_parameter("wave_height", 0.0)
	material.set_shader_parameter("reflection_steps", 0)
	var bottom := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32: bottom.set_pixel(x, y, Color(0.5, 0.3, 0.1) if (x / 4 + y / 4) % 2 else Color(0.1, 0.3, 0.5))
	material.set_shader_parameter("bottom_texture", ImageTexture.create_from_image(bottom))
	var flat := await render()
	material.set_shader_parameter("virtual_bottom_enabled", false)
	var void_image := await render()
	check(difference(flat, void_image) > 0.02, "Puddle requires actual floor geometry to show its bottom")
	material.set_shader_parameter("virtual_bottom_enabled", true)
	check(puddle.add_ripple(Vector3.ZERO, 0.15, 0.3, 2.0), "Cannot spawn water disturbance")
	puddle.set_water_time(0.6)
	var disturbed := await render()
	check(difference(disturbed, flat) > 0.003, "Surface ripple did not distort virtual-bottom refraction or lighting")
	var mask := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	mask.fill(Color.WHITE)
	material.set_shader_parameter("coverage_mask", ImageTexture.create_from_image(mask))
	material.set_shader_parameter("invert_coverage_mask", true)
	material.set_shader_parameter("use_coverage_mask", true)
	var excluded := await render()
	puddle.hide()
	var background := await render()
	check(difference(excluded, background) < 0.001, "Opaque floor mask does not exclude puddle water")
	puddle.show()
	mask.fill(Color.TRANSPARENT)
	material.set_shader_parameter("coverage_mask", ImageTexture.create_from_image(mask))
	var included := await render()
	check(difference(included, background) > 0.02, "Alpha cutout does not reveal water")
	var directory := OS.get_environment("MGS_WATER_TEST_OUTPUT")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		flat.save_png(directory.path_join("puddle-flat.png"))
		disturbed.save_png(directory.path_join("puddle-ripple.png"))
	print("MGS_WATER_PUDDLE_TEST failures=%d ripple_difference=%.6f" % [failures, difference(disturbed, flat)])
	viewport.queue_free()
	await process_frame
	quit(1 if failures else 0)
