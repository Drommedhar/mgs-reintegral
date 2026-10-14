extends SceneTree

const Appearance = preload("res://object_appearance.gd")
var failures := 0
var viewport := SubViewport.new()
var camera := Camera3D.new()
var appearance := Appearance.new()

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func quad(color: Color, size: Vector2, position: Vector3) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = QuadMesh.new()
	mesh.mesh.size = size
	mesh.position = position
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	mesh.material_override = material
	viewport.add_child(mesh)
	return mesh

func frame() -> Image:
	for _index in 6: await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	viewport.size = Vector2i(128, 128)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2 if "--fsr2" in OS.get_cmdline_user_args() else Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = 0.75 if "--fsr2" in OS.get_cmdline_user_args() else 1.0
	root.add_child(viewport)
	viewport.add_child(camera)
	camera.fov = 90
	camera.environment = Environment.new()
	camera.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	camera.environment.ambient_light_color = Color.WHITE
	camera.environment.ambient_light_energy = 1.0
	var backdrop := quad(Color(0.05, 0.25, 0.8), Vector2(10, 10), Vector3(0, 0, -4))
	var actor := quad(Color(0.8, 0.05, 0.05), Vector2(2, 2), Vector3(0, 0, -2))
	var original: Material = actor.material_override
	check(appearance.initialize({}).is_empty(), "Cannot initialize camouflage")
	appearance.template.set_shader_parameter("distortion", 0.0)
	appearance.template.set_shader_parameter("tint_strength", 0.0)
	appearance.template.set_shader_parameter("rim_energy", 0.0)
	var entry := {"meshes": [actor], "material_stages": {}, "appearance": {"kind": 1, "amount": 0.0, "tint": Vector3.ONE}}
	appearance.apply(entry, "active", null)
	var visible := (await frame()).get_pixel(64, 64)
	check(visible.r > visible.b * 3, "Transition start lost base albedo: %s" % visible)
	entry.appearance = {"kind": 1, "amount": 1.0, "tint": Vector3.ONE}
	appearance.apply(entry, "active", null)
	var cloaked := (await frame()).get_pixel(64, 64)
	check(cloaked.b > cloaked.r * 3, "Cloak did not sample Godot backdrop: %s" % cloaked)
	actor.hide()
	var clear := (await frame()).get_pixel(64, 64)
	check(Vector3(clear.r, clear.g, clear.b).distance_to(Vector3(cloaked.r, cloaked.g, cloaked.b)) < 0.06, "Refraction double-applied color transfer: clear=%s cloak=%s" % [clear, cloaked])
	actor.show()
	var occluder := quad(Color.GREEN, Vector2(0.6, 0.6), Vector3(0, 0, -1))
	var blocked := (await frame()).get_pixel(64, 64)
	check(blocked.g > blocked.b * 3, "Camouflage drew through opaque foreground: %s" % blocked)
	occluder.free()
	backdrop.material_override.albedo_color = Color(0.7, 0.5, 0.05)
	camera.position.x = 0.1
	var changed := (await frame()).get_pixel(64, 64)
	check(changed.r > changed.b * 3, "Camouflage froze its background sample after scene/camera changes")
	appearance.prepare(entry, "")
	check(actor.material_override == original, "Render material was not restored")
	var restored := (await frame()).get_pixel(64, 64)
	check(restored.r > restored.g * 3, "Restored character stayed camouflaged")
	actor.free()
	backdrop.free()
	await check_refraction()
	print("MGS_CAMOUFLAGE_RENDER_TEST failures=%d fsr2=%s" % [failures, "--fsr2" in OS.get_cmdline_user_args()])
	quit(1 if failures else 0)

func check_refraction() -> void:
	viewport.size = Vector2i(256, 256)
	camera.position = Vector3.ZERO
	var pattern := Image.create(256, 256, false, Image.FORMAT_RGB8)
	for y in 256:
		for x in 256:
			var level := 0.3 + 0.4 * float(x) / 255.0
			if x % 24 < 3 or y % 24 < 3: level = 0.1
			pattern.set_pixel(x, y, Color(level, level, level))
	var backdrop := quad(Color.WHITE, Vector2(8, 8), Vector3(0, 0, -4))
	backdrop.material_override.albedo_texture = ImageTexture.create_from_image(pattern)
	var clear := await frame()
	var actor := MeshInstance3D.new()
	actor.mesh = SphereMesh.new()
	actor.mesh.radius = 0.8
	actor.mesh.height = 1.6
	actor.material_override = StandardMaterial3D.new()
	actor.position.z = -2.0
	viewport.add_child(actor)
	var cloak := Appearance.new()
	check(cloak.initialize({}).is_empty(), "Cannot initialize refractive cloak")
	var entry := {"meshes": [actor], "material_stages": {}, "appearance": {"kind": 1, "amount": 1.0, "tint": Vector3.ONE}}
	cloak.apply(entry, "active", null)
	var neutral := await frame()
	var displaced := 0
	for y in range(96, 160):
		for x in range(96, 160):
			if absf(neutral.get_pixel(x, y).r - clear.get_pixel(x, y).r) > 0.08: displaced += 1
	check(displaced > 200, "Cloak did not displace structured background: %d pixels" % displaced)
	var ninja := neutral.get_pixel(148, 128)
	check(absf(ninja.g - ninja.r) < 0.02 and absf(ninja.b - ninja.r) < 0.02, "Ninja cloak introduced a tint: %s" % ninja)
	entry.appearance = {"kind": 1, "amount": 1.0, "tint": Vector3(1.0, 1.25, 0.75)}
	cloak.apply(entry, "active", null)
	var green := await frame()
	var snake := green.get_pixel(148, 128)
	check(snake.g > snake.r * 1.05 and snake.b < snake.r * 0.95, "Snake cloak lost native green tint: %s" % snake)
	var folder := "res://.generated/camouflage-refraction/" + ("fsr2" if "--fsr2" in OS.get_cmdline_user_args() else "native")
	DirAccess.make_dir_recursive_absolute(folder)
	for sample in [["background", clear], ["ninja", neutral], ["snake", green]]:
		check(sample[1].save_png(folder.path_join(sample[0] + ".png")) == OK, "Cannot save refraction proof")
	await check_foreground_refraction(actor)
	# A zero-refraction material must reproduce the background away from the image center too.
	var material: ShaderMaterial = actor.get_active_material(0)
	material.set_shader_parameter("index_of_refraction", 1.0)
	material.set_shader_parameter("tint_strength", 0.0)
	material.set_shader_parameter("rim_energy", 0.0)
	var straight := await frame()
	for point in [Vector2i(107, 104), Vector2i(147, 151)]:
		var expected := clear.get_pixelv(point)
		var actual := straight.get_pixelv(point)
		check(Vector3(actual.r, actual.g, actual.b).distance_to(Vector3(expected.r, expected.g, expected.b)) < 0.06, "Refraction shifted/flipped the undisplaced image at %s" % point)
	print("MGS_CAMOUFLAGE_REFRACTION displaced_pixels=%d ninja=%s snake=%s" % [displaced, ninja, snake])

func check_foreground_refraction(actor: MeshInstance3D) -> void:
	var material: ShaderMaterial = actor.get_active_material(0)
	material.set_shader_parameter("distortion", 0.1)
	material.set_shader_parameter("index_of_refraction", 2.0)
	var occluder := quad(Color.RED, Vector2(0.14, 1.0), Vector3(0.19, 0, -1.0))
	var result := await frame()
	var leaked := 0
	# The foreground bar ends at x=161; these samples lie outside its filtered edge.
	for y in range(110, 146):
		for x in range(165, 173):
			var pixel := result.get_pixel(x, y)
			if pixel.r > pixel.g + 0.1: leaked += 1
	check(leaked == 0, "Refraction pulled foreground pixels into the background: %d" % leaked)
	occluder.free()
