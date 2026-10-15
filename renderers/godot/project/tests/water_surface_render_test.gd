extends SceneTree

var viewport := SubViewport.new()
var camera := Camera3D.new()
var water := MeshInstance3D.new()
var material := ShaderMaterial.new()
var region: Node3D
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	create_timer(60).timeout.connect(quit.bind(1))
	run.call_deferred()

func box(position: Vector3, size: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	node.mesh = BoxMesh.new()
	node.mesh.size = size
	node.position = position
	var appearance := StandardMaterial3D.new()
	appearance.albedo_color = color
	appearance.roughness = 0.8
	node.material_override = appearance
	viewport.add_child(node)

func render() -> Image:
	for _frame in 4:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func difference(first: Image, second: Image) -> float:
	var total := 0.0
	for y in first.get_height():
		for x in first.get_width():
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			total += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
	return total / (first.get_width() * first.get_height())

func run() -> void:
	if "--fsr2" in OS.get_cmdline_user_args(): preload("res://scene_view.gd").configure_rendering(viewport, root)
	viewport.size = Vector2i(480, 320)
	viewport.own_world_3d = true
	root.add_child(viewport)
	viewport.add_child(camera)
	camera.position = Vector3(0, 2.5, 6)
	camera.look_at(Vector3(0, 0, -0.5))
	camera.environment = Environment.new()
	camera.environment.background_mode = Environment.BG_COLOR
	camera.environment.background_color = Color(0.08, 0.11, 0.15)
	camera.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	camera.environment.ambient_light_color = Color.WHITE
	camera.environment.ambient_light_energy = 0.5
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -25, 0)
	light.light_energy = 1.2
	light.shadow_enabled = true
	viewport.add_child(light)
	box(Vector3(0, -1.5, 0), Vector3(10, 0.3, 10), Color(0.35, 0.3, 0.23))
	box(Vector3(-1.4, 1.4, -2), Vector3(0.8, 3, 0.8), Color(0.9, 0.2, 0.08))
	box(Vector3(1.1, 0.8, -1.8), Vector3(1, 2, 1), Color(0.08, 0.3, 0.85))
	water.free()
	region = load("res://addons/mgs_water/water_region.tscn").instantiate()
	viewport.add_child(region)
	region.set_process(false)
	region.caustics_enabled = false
	water = region.get_node("Surface")
	material = water.material_override
	var reflected := await render()
	var foreground := Vector2i(camera.unproject_position(Vector3(-1.4,1.4,-2)))
	region.hide()
	var without_water := await render()
	var difference_at_object := reflected.get_pixelv(foreground) - without_water.get_pixelv(foreground)
	check(absf(difference_at_object.r) + absf(difference_at_object.g) + absf(difference_at_object.b) < 0.04, "Water smeared an opaque foreground object")
	region.show()
	material.set_shader_parameter("reflection_steps", 0)
	var fallback := await render()
	check(difference(reflected, fallback) > 0.0001, "SSR did not contribute reflected scene color")
	material.set_shader_parameter("water_time", 0.8)
	var animated := await render()
	check(difference(animated, fallback) > 0.0001, "Water waves did not change shading")
	var scaling_mode := viewport.scaling_3d_mode
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.use_taa = false
	region.set("waves/speed", 0.0)
	var frozen := await render()
	material.set_shader_parameter("water_time", 3.0)
	var frozen_change := difference(frozen, await render())
	print("MGS_WATER_SPEED frozen_difference=%.8f speed=%s" % [frozen_change, material.get_shader_parameter("wave_speed")])
	check(frozen_change < 0.000001, "Zero wave speed did not freeze surface displacement and normals")
	region.set("waves/speed", 2.0)
	check(difference(frozen, await render()) > 0.0001, "Root wave speed control did not affect rendered water")
	viewport.scaling_3d_mode = scaling_mode
	camera.position = Vector3(0, -0.6, 2)
	camera.look_at(Vector3(0, 0.4, -2))
	var submerged := await render()
	region.underwater_enabled = false
	var clear_underwater := await render()
	check(difference(submerged, clear_underwater) > 0.01, "Bounded underwater fog did not affect submerged view")
	var directory := OS.get_environment("MGS_WATER_TEST_OUTPUT")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		reflected.save_png(directory.path_join("surface-reflection.png"))
		fallback.save_png(directory.path_join("surface-fallback.png"))
		submerged.save_png(directory.path_join("surface-underwater.png"))
	print("MGS_WATER_SURFACE_TEST failures=%d reflection_difference=%.6f" % [failures, difference(reflected, fallback)])
	viewport.queue_free()
	await process_frame
	quit(1 if failures else 0)
