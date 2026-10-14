extends SceneTree

var viewport := SubViewport.new()
var camera := Camera3D.new()
var receiver := MeshInstance3D.new()
var material := ShaderMaterial.new()
var light := OmniLight3D.new()
var occluder := MeshInstance3D.new()
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func render() -> Image:
	for _frame in 3:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func luminance(image: Image, point: Vector3) -> float:
	var pixel := Vector2i(camera.unproject_position(point))
	var total := 0.0
	for x in range(pixel.x - 2, pixel.x + 3):
		for y in range(pixel.y - 2, pixel.y + 3): total += image.get_pixel(x, y).get_luminance()
	return total / 25.0

func run() -> void:
	viewport.size = Vector2i(320, 240)
	viewport.own_world_3d = true
	viewport.positional_shadow_atlas_size = 2048
	root.add_child(viewport)
	viewport.add_child(camera)
	camera.position = Vector3(0, 5, 6)
	camera.look_at(Vector3(0, -1, 0))
	camera.environment = Environment.new()
	camera.environment.background_mode = Environment.BG_COLOR
	camera.environment.background_color = Color.BLACK
	camera.environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	floor_mesh.mesh.size = Vector2(12, 12)
	floor_mesh.position.y = -1
	var black := StandardMaterial3D.new()
	black.albedo_color = Color.BLACK
	black.roughness = 1.0
	black.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	floor_mesh.material_override = black
	viewport.add_child(floor_mesh)
	viewport.add_child(light)
	light.position = Vector3(-2, 3, 0)
	light.light_energy = 5.0
	light.omni_range = 15
	light.shadow_enabled = true
	light.shadow_bias = 0.01
	light.shadow_normal_bias = 0.02
	occluder.mesh = BoxMesh.new()
	occluder.mesh.size = Vector3(1.3, 0.2, 1.3)
	occluder.position = Vector3(-2, 0.5, 0)
	occluder.material_override = black
	viewport.add_child(occluder)
	receiver.mesh = QuadMesh.new()
	receiver.mesh.size = Vector2(2, 2)
	receiver.custom_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 4, 8))
	receiver.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material.shader = load("res://addons/mgs_water/caustics.gdshader")
	material.set_shader_parameter("water_inverse", Transform3D.IDENTITY)
	material.set_shader_parameter("diagnostic_flat", true)
	material.set_shader_parameter("strength", 1.0)
	receiver.material_override = material
	viewport.add_child(receiver)
	var image := await render()
	var lit := luminance(image, Vector3(1, -1, 0))
	var shaded := luminance(image, Vector3(-2, -1, 0))
	var dry := luminance(image, Vector3(4.8, -1, 0))
	check(lit > 0.02, "Omni light does not illuminate the reconstructed receiver")
	check(shaded < lit * 0.2, "Caustics pass through an opaque shadow caster")
	check(dry < 0.01, "Caustics extend outside water bounds")
	light.hide()
	var dark := await render()
	check(luminance(dark, Vector3(1, -1, 0)) < 0.01, "Caustics glow without a light source")
	light.show()
	occluder.hide()
	var unblocked := await render()
	check(luminance(unblocked, Vector3(-2, -1, 0)) > shaded + 0.02, "Occluder removal did not restore caustics")
	var scaling_mode := viewport.scaling_3d_mode
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.use_taa = false
	material.set_shader_parameter("diagnostic_flat", false)
	material.set_shader_parameter("caustic_speed", 0.0)
	var frozen := await render()
	material.set_shader_parameter("water_time", 3.0)
	check(frozen.get_data() == (await render()).get_data(), "Zero caustic speed did not freeze the pattern")
	material.set_shader_parameter("caustic_speed", 2.0)
	check(frozen.get_data() != (await render()).get_data(), "Caustic speed did not animate the pattern")
	material.set_shader_parameter("diagnostic_flat", true)
	viewport.scaling_3d_mode = scaling_mode
	camera.position = Vector3(0, -0.2, 3)
	camera.look_at(Vector3(0, -1, 0))
	var underwater := await render()
	check(luminance(underwater, Vector3(1, -1, 0)) > 0.02, "Underwater caustics require the water surface in view")
	light.hide()
	var spot := SpotLight3D.new()
	spot.position = Vector3(0, 3, 0)
	spot.spot_range = 12
	spot.spot_angle = 45
	spot.light_energy = 5
	spot.shadow_enabled = true
	viewport.add_child(spot)
	spot.look_at(Vector3(0, -1, 0), Vector3.FORWARD)
	var spotlight := await render()
	check(luminance(spotlight, Vector3(1, -1, 0)) > 0.02, "SpotLight does not illuminate the receiver")
	material.set_shader_parameter("water_inverse", Transform3D(Basis.IDENTITY, Vector3(0, 2, 0)))
	var below_volume := await render()
	check(luminance(below_volume, Vector3(1, -1, 0)) < 0.01, "Dry receiver above a second water height remains illuminated")
	var directory := OS.get_environment("MGS_WATER_TEST_OUTPUT")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		image.save_png(directory.path_join("caustic-occlusion.png"))
		unblocked.save_png(directory.path_join("caustic-unblocked.png"))
		underwater.save_png(directory.path_join("caustic-underwater.png"))
	print("MGS_WATER_CAUSTICS_TEST failures=%d lit=%.4f shadow=%.4f dry=%.4f" % [failures, lit, shaded, dry])
	viewport.queue_free()
	await process_frame
	quit(1 if failures else 0)
