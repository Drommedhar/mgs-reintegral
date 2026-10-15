extends SceneTree

const DiscMap = preload("res://addons/mgs_editor/disc_map.gd")
const Coordinates = preload("res://map_coordinates.gd")
const PbrMaterials = preload("res://pbr_materials.gd")
const SceneView = preload("res://scene_view.gd")
const ShaderWarmup = preload("res://shader_warmup.gd")
var viewport := SubViewport.new()
var light := OmniLight3D.new()
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func frame() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func brighter(a: Image, b: Image) -> int:
	var pixels := 0
	for y in a.get_height():
		for x in a.get_width():
			if b.get_pixel(x, y).get_luminance() - a.get_pixel(x, y).get_luminance() > 0.03: pixels += 1
	return pixels

func palette(value: Color, format: Image.Format) -> ImageTexture:
	var image := Image.create(1, 1, false, format)
	image.fill(value)
	return ImageTexture.create_from_image(image)

func light_response(label: String) -> void:
	light.hide()
	var dark := await frame()
	light.show()
	var lit := await frame()
	var pixels := brighter(dark, lit)
	print("MGS_IMPORTED_LIGHTING %s illuminated_pixels=%d" % [label, pixels])
	check(pixels > 1000, label + ": light above the imported floor did not illuminate its front face")
	light.position.x = -light.position.x
	var moved := await frame()
	check(brighter(lit, moved) > 200 and brighter(moved, lit) > 200, label + ": imported geometry did not respond to a moving light")

func check_warmup(map: Node3D) -> void:
	var scene := SceneView.new()
	root.add_child(scene)
	check(scene.materials.initialize({}, scene.mods, "").is_empty(), "Warm-up material initialization failed")
	scene.templates.fixture = map.duplicate()
	var mesh: MeshInstance3D = scene.templates.fixture.find_children("mesh_000", "MeshInstance3D", true, false)[0]
	var before := mesh.mesh.surface_get_arrays(0)
	var sparse := MeshInstance3D.new()
	sparse.name = "mesh_sparse"
	var arrays := before.duplicate()
	for attribute in [Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]: arrays[attribute] = null
	sparse.mesh = ArrayMesh.new()
	sparse.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	scene.templates.fixture.add_child(sparse)
	var children := scene.get_child_count()
	await ShaderWarmup.prepare(scene, root)
	check(scene.get_child_count() == children, "Warm-up left temporary lights or meshes in the scene")
	check(mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == before[Mesh.ARRAY_VERTEX], "Warm-up modified original geometry")
	scene.free()

func run() -> void:
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.use_taa = false
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.size = Vector2i(192, 192)
	viewport.own_world_3d = true
	viewport.positional_shadow_atlas_size = 2048
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.position = Vector3(0, 6, 7)
	camera.look_at(Vector3.ZERO)
	camera.environment = Environment.new()
	camera.environment.background_mode = Environment.BG_COLOR
	camera.environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	var loader := DiscMap.new()
	var catalog := {"assets": {"floor": {"path": "floor.gltf", "parts": 1}}, "maps": {"fixture": {"models": ["floor"]}}}
	var map := loader.load_map("res://.generated/lighting-test", catalog, "fixture")
	check(map != null, loader.error)
	if map == null:
		viewport.free()
		light.free()
		quit(1)
		return
	await check_warmup(map)
	map.transform = Coordinates.ROTATION
	viewport.add_child(map)
	var mesh: MeshInstance3D = map.find_children("mesh_000", "MeshInstance3D", true, false)[0]
	var material := mesh.get_active_material(0) as StandardMaterial3D
	light.position = Vector3(-2, 4, 2)
	light.omni_range = 12
	light.light_energy = 4
	viewport.add_child(light)
	await light_response("editor StandardMaterial3D")
	var pbr := PbrMaterials.new()
	check(pbr.initialize({}).is_empty(), "Cannot initialize runtime PBR material")
	var runtime_material := ShaderMaterial.new()
	runtime_material.shader = preload("res://reference.gdshader")
	runtime_material.set_shader_parameter("albedo_texture", material.albedo_texture)
	runtime_material.set_shader_parameter("shade_texture", palette(Color.WHITE, Image.FORMAT_RGBA8))
	runtime_material.set_shader_parameter("packet_texture", palette(Color(0.5, 0.5, 2000, 0), Image.FORMAT_RGBAF))
	pbr.apply(runtime_material, "fixture", false)
	mesh.set_surface_override_material(0, runtime_material)
	await light_response("runtime PBR")
	runtime_material.set_shader_parameter("shade_texture", palette(Color(1, 1, 1, 0), Image.FORMAT_RGBA8))
	await light_response("runtime PBR with native projected faces culled")
	var box := MeshInstance3D.new()
	box.mesh = BoxMesh.new()
	box.position = Vector3(0, 1, 0)
	viewport.add_child(box)
	var unshadowed := await frame()
	light.shadow_enabled = true
	var shadowed := await frame()
	check(brighter(shadowed, unshadowed) > 100, "Imported floor did not receive a dynamic shadow")
	box.hide()
	light.shadow_enabled = false
	mesh.set_surface_override_material(0, material)
	var arrays := mesh.mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for index in normals.size(): normals[index] = -normals[index]
	arrays[Mesh.ARRAY_NORMAL] = normals
	var inverted := ArrayMesh.new()
	inverted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.mesh = inverted
	mesh.set_surface_override_material(0, material)
	light.hide()
	var wrong_dark := await frame()
	light.show()
	var wrong_lit := await frame()
	check(brighter(wrong_dark, wrong_lit) < 20, "Lighting regression no longer distinguishes inward normals")
	viewport.free()
	print("MGS_IMPORTED_LIGHTING_TEST failures=%d" % failures)
	quit(1 if failures else 0)
