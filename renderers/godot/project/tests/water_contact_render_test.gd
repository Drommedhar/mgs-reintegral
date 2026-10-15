extends SceneTree

var viewport := SubViewport.new()
var camera := Camera3D.new()
var region: Node3D
var material: ShaderMaterial
var failures := 0

func check(value: bool, message: String) -> void:
	if value: return
	failures += 1
	push_error(message)

func _initialize() -> void:
	create_timer(45).timeout.connect(quit.bind(1))
	run.call_deferred()

func sample() -> Color:
	for frame in 4:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image().get_pixel(128, 96)

func delta(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)

func run() -> void:
	viewport.size = Vector2i(256, 192)
	viewport.own_world_3d = true
	root.add_child(viewport)
	viewport.add_child(camera)
	camera.position = Vector3(0, 2, 3)
	camera.look_at(Vector3.ZERO)
	camera.environment = Environment.new()
	camera.environment.background_mode = Environment.BG_COLOR
	camera.environment.background_color = Color.BLACK
	camera.environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	region = load("res://addons/mgs_water/water_region.tscn").instantiate()
	viewport.add_child(region)
	region.set_process(false)
	region.caustics_enabled = false
	region.underwater_enabled = false
	region.absorption = Vector3.ZERO
	region.water_color = Color(0.2, 0.35, 0.3)
	material = region.get_node("Surface").material_override
	material.set_shader_parameter("wave_height", 0.0)
	material.set_shader_parameter("reflection_steps", 0)
	var missing_black := await sample()
	camera.environment.background_color = Color(0.9, 0.05, 0.6)
	var missing_magenta := await sample()
	check(delta(missing_black, missing_magenta) < 0.01, "Missing geometry leaks the background through water")
	check(missing_black.g > 0.12, "Missing geometry produces black water instead of its fallback color")
	camera.environment.background_color = Color.BLACK
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	floor_mesh.mesh.size = Vector2(8, 8)
	floor_mesh.position.y = -0.02
	var floor_material := StandardMaterial3D.new()
	floor_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_material.albedo_color = Color(0.65, 0.2, 0.08)
	floor_mesh.material_override = floor_material
	viewport.add_child(floor_mesh)
	region.absorption = Vector3(8, 8, 8)
	material.set_shader_parameter("intersection_fade_distance", 0.0)
	var hard := await sample()
	material.set_shader_parameter("intersection_fade_distance", 0.3)
	var soft := await sample()
	region.hide()
	var uncovered := await sample()
	check(delta(soft, uncovered) < delta(hard, uncovered) * 0.25, "Water does not soften its shallow geometry intersection")
	region.show()
	floor_mesh.position.y = -2.0
	var deep_soft := await sample()
	material.set_shader_parameter("intersection_fade_distance", 0.0)
	check(delta(deep_soft, await sample()) < 0.005, "Intersection fade changes deep water")
	print("MGS_WATER_CONTACT_TEST failures=%d background_delta=%.6f hard=%.6f soft=%.6f" % [failures, delta(missing_black, missing_magenta), delta(hard, uncovered), delta(soft, uncovered)])
	viewport.queue_free()
	await process_frame
	quit(1 if failures else 0)
