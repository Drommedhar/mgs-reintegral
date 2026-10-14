extends SceneTree

var viewport := SubViewport.new()
var camera := Camera3D.new()
var failures := 0

func _initialize() -> void:
	create_timer(30).timeout.connect(quit.bind(1))
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func render() -> Image:
	for _frame in 3:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func difference(a: Image, b: Image) -> float:
	var result := 0.0
	for y in a.get_height():
		for x in a.get_width(): result += absf(a.get_pixel(x,y).get_luminance() - b.get_pixel(x,y).get_luminance())
	return result / (a.get_width() * a.get_height())

func run() -> void:
	preload("res://scene_view.gd").configure_rendering(viewport, root)
	viewport.size = Vector2i(480,320)
	viewport.own_world_3d = true
	root.add_child(viewport)
	viewport.add_child(camera)
	camera.position = Vector3(0,2,3)
	camera.look_at(Vector3.ZERO)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,-25,0)
	viewport.add_child(light)
	var surface := MeshInstance3D.new()
	surface.name = "ColdMetal"
	surface.mesh = PlaneMesh.new()
	surface.mesh.size = Vector2(4,4)
	var base := StandardMaterial3D.new()
	base.albedo_color = Color(0.18,0.13,0.07)
	base.metallic = 0.35
	base.roughness = 0.6
	surface.mesh.material = base
	viewport.add_child(surface)
	var bare := await render()
	var frost := Node3D.new()
	frost.set_script(load("res://addons/mgs_water/frost_layer.gd"))
	frost.targets.assign([NodePath("../ColdMetal")])
	frost.material = load("res://addons/mgs_water/frost.tres").duplicate()
	frost.material.set_shader_parameter("coverage", 0.55)
	viewport.add_child(frost)
	var coated := await render()
	check(base.next_pass == null and base.albedo_color == Color(0.18,0.13,0.07), "Frost mutated the source material")
	check(difference(bare, coated) > 0.001, "Frost did not change illuminated surface")
	var mask_image := Image.create(2,2,false,Image.FORMAT_RGB8)
	mask_image.fill(Color.BLACK)
	frost.material.set_shader_parameter("coverage_mask", ImageTexture.create_from_image(mask_image))
	frost.apply()
	var masked := await render()
	check(difference(bare, masked) < 1.0 / 1024.0, "Black author mask did not restore the original material within output quantization")
	frost.material.set_shader_parameter("coverage_mask", null)
	frost.material.set_shader_parameter("submerged_height", 2.0)
	frost.apply()
	check(difference(bare, await render()) < 1.0 / 1024.0, "Frost coated a submerged surface")
	frost.restore()
	check(surface.get_surface_override_material(0) == null, "Frost removal lost original surface material")
	frost.material.set_shader_parameter("submerged_height", -1.5)
	frost.material.set_shader_parameter("crystal_strength", 0.0)
	frost.apply()
	var plain_motion := await measure_motion()
	frost.material.set_shader_parameter("crystal_strength", 0.8)
	frost.apply()
	var crystal_motion := await measure_motion()
	check(crystal_motion <= plain_motion * 1.2 + 1.0 / 1024.0, "Subpixel frost facets added unstable shimmer under FSR2")
	print("MGS_FROST_MOTION plain=%.6f crystals=%.6f" % [plain_motion, crystal_motion])
	var directory := OS.get_environment("MGS_WATER_TEST_OUTPUT")
	if not directory.is_empty():
		coated.save_png(directory.path_join("frost-coated.png"))
		bare.save_png(directory.path_join("frost-bare.png"))
		masked.save_png(directory.path_join("frost-masked.png"))
	print("MGS_FROST_RENDER_TEST failures=%d difference=%.6f" % [failures,difference(bare,coated)])
	viewport.queue_free()
	await process_frame
	quit(1 if failures else 0)

func measure_motion() -> float:
	camera.position.x = 0
	for _frame in 24: await render()
	var previous := await render()
	var total := 0.0
	for frame in 24:
		camera.position.x = frame * 0.002
		var current := await render()
		total += difference(previous,current)
		previous = current
	return total / 24.0
