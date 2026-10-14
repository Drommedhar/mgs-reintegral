extends SceneTree

const PbrMaterials = preload("res://pbr_materials.gd")
const ReferenceMaterials = preload("res://reference_materials.gd")
var viewport := SubViewport.new()
var light := OmniLight3D.new()
var pbr := PbrMaterials.new()
var material: ShaderMaterial
var packets: ImageTexture
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func texture(color: Color, format: Image.Format = Image.FORMAT_RGBA8) -> ImageTexture:
	var image := Image.create(1, 1, false, format)
	image.fill(color)
	return ImageTexture.create_from_image(image)

func make_material() -> ShaderMaterial:
	var result := ShaderMaterial.new()
	pbr.apply(result, "fixture", false)
	result.set_shader_parameter("albedo_texture", texture(Color(0.7, 0.45, 0.2)))
	result.set_shader_parameter("shade_texture", texture(Color(0.5, 0.5, 0.5, 1)))
	result.set_shader_parameter("packet_texture", packets)
	return result

func mesh(resource: Mesh, position: Vector3, surface: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var arrays := resource.surface_get_arrays(0)
	arrays[Mesh.ARRAY_TEX_UV2] = arrays[Mesh.ARRAY_TEX_UV]
	var indexed := ArrayMesh.new()
	indexed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	node.mesh = indexed
	node.position = position
	node.material_override = surface
	viewport.add_child(node)
	return node

func frame() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func changed(a: Image, b: Image) -> int:
	var count := 0
	for y in a.get_height():
		for x in a.get_width():
			var first := a.get_pixel(x, y)
			var second := b.get_pixel(x, y)
			if absf(first.r - second.r) + absf(first.g - second.g) + absf(first.b - second.b) > 0.08: count += 1
	return count

func brightness(image: Image) -> float:
	var sum := 0.0
	for y in image.get_height():
		for x in image.get_width(): sum += image.get_pixel(x, y).get_luminance()
	return sum

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.use_taa = false
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	check(pbr.initialize({}).is_empty(), "PBR initialization failed")
	var palette := Image.create(64, 64, false, Image.FORMAT_RGBAF)
	for y in 64:
		for x in 64: palette.set_pixel(x, y, Color(x / 63.0, y / 63.0, 2000, 0))
	packets = ImageTexture.create_from_image(palette)
	viewport.size = Vector2i(128, 128)
	viewport.own_world_3d = true
	viewport.positional_shadow_atlas_size = 2048
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 6, 7)
	camera.environment = Environment.new()
	camera.environment.background_mode = Environment.BG_COLOR
	camera.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	camera.environment.ambient_light_color = Color.WHITE
	camera.environment.ambient_light_energy = 0.05
	viewport.add_child(camera)
	camera.look_at(Vector3.ZERO)
	var plane := PlaneMesh.new()
	plane.size = Vector2(8, 8)
	mesh(plane, Vector3.ZERO, make_material())
	var sphere := SphereMesh.new()
	sphere.radius = 1
	sphere.height = 2
	material = make_material()
	var ball := mesh(sphere, Vector3(0, 1, 0), material)
	light.position = Vector3(-2, 4, 2)
	light.omni_range = 12
	light.light_energy = 4
	viewport.add_child(light)
	var unshadowed := await frame()
	material.shader = pbr.two_sided
	var path := "user://pbr-material-%d.tres" % Time.get_ticks_usec()
	check(ResourceSaver.save(material, path) == OK, "Cannot save generated PBR material")
	material = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as ShaderMaterial
	ball.material_override = material
	var restored := await frame()
	check(changed(unshadowed, restored) < 10, "Saved/reloaded PBR shader changed the rendered image")
	light.shadow_enabled = true
	var shadowed := await frame()
	check(changed(unshadowed, shadowed) > 30 and brightness(shadowed) < brightness(unshadowed) - 1, "Godot shadow did not darken the PBR receiver")
	light.position.x = 2
	var moved := await frame()
	check(changed(shadowed, moved) > 100, "Moving dynamic light did not update lighting and shadows")
	material.set_shader_parameter("pbr_metallic", 1.0)
	material.set_shader_parameter("pbr_roughness", 0.1)
	var metal := await frame()
	check(changed(moved, metal) > 50, "PBR metallic/specular response did not reach the image")
	material.set_shader_parameter("pbr_roughness", 0.9)
	var rough := await frame()
	check(changed(metal, rough) > 30, "PBR roughness did not change specular highlights")
	material.set_shader_parameter("normal_texture", texture(Color(0.85, 0.5, 0.85)))
	material.set_shader_parameter("has_normal", true)
	var normal := await frame()
	check(changed(rough, normal) > 30, "Normal map did not change lighting")
	material.set_shader_parameter("orm_texture", texture(Color(0.2, 0.2, 0.1)))
	material.set_shader_parameter("has_orm", true)
	var orm := await frame()
	check(changed(normal, orm) > 30, "ORM map did not affect the PBR material")
	material.set_shader_parameter("emission_texture", texture(Color.RED))
	material.set_shader_parameter("has_emission", true)
	var emissive := await frame()
	check(changed(orm, emissive) > 50, "Emission map did not contribute to the image")
	var authored := ORMMaterial3D.new()
	authored.orm_texture = texture(Color(1, 0.3, 0.7))
	authored.normal_enabled = true
	authored.normal_texture = texture(Color(0.5, 0.5, 1))
	var replacement := ReferenceMaterials.new().replacement_material(authored, "lit") as ORMMaterial3D
	check(replacement != null and replacement.orm_texture == authored.orm_texture and replacement.normal_enabled,
		"Replacement material lost its authored PBR maps")
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.queue_free()
	await process_frame
	print("MGS_PBR_LIGHTING_TEST failures=%d" % failures)
	quit(1 if failures else 0)
