extends SceneTree

const SceneView = preload("res://scene_view.gd")
const ASSET = "mgs/integral-j/disc1/stage/init/0001.k"
var viewport := SubViewport.new()
var scene := SceneView.new()
var lamp := OmniLight3D.new()
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func snapshot(flags: int, x: float = 0.0) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(100)
	data.encode_float(8, 1)
	data.encode_float(28, 1)
	data.encode_float(48, 1)
	data.encode_float(56, 320)
	data.encode_u32(60, 1)
	data.encode_float(64, 1.0)
	data.encode_u32(68, 1)
	data.encode_u32(72, 1)
	for i in 4: data[76 + i] = "init".unicode_at(i)
	data.encode_u32(88, 1)
	data.encode_u32(92, 1)
	data.encode_u32(96, 4)
	data.append_array(PackedFloat32Array([1, 0, 0, x * 1000, 0, 1, 0, -1000, 0, 0, 1, 0]).to_byte_array())
	data.append_array(PackedInt32Array([flags]).to_byte_array())
	for _corner in 4: data.append_array(PackedByteArray([128, 128, 128, 0]))
	for _corner in 4: data.append_array(PackedFloat32Array([0, 0, 0, 0]).to_byte_array())
	data.append_array(PackedInt32Array([0, 0]).to_byte_array())
	return data

func model() -> Node3D:
	var node := Node3D.new()
	var skeleton := Skeleton3D.new()
	node.add_child(skeleton)
	skeleton.add_bone("part_000")
	var mesh := MeshInstance3D.new()
	mesh.name = "mesh_000"
	var box := BoxMesh.new()
	box.size = Vector3(0.6, 2, 0.4)
	var arrays := box.surface_get_arrays(0)
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var uvs := PackedVector2Array()
	for _vertex in arrays[Mesh.ARRAY_VERTEX].size():
		bones.append_array([0, 0, 0, 0])
		weights.append_array([1, 0, 0, 0])
		uvs.append(Vector2(0.75, 0.75))
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var palette_uvs := PackedVector2Array()
	for _vertex in uvs.size(): palette_uvs.append(Vector2(0.5 / 256.0, 0.5))
	arrays[Mesh.ARRAY_TEX_UV2] = palette_uvs
	mesh.mesh = ArrayMesh.new()
	mesh.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.resource_name = "0002"
	mesh.mesh.surface_set_material(0, material)
	mesh.skin = Skin.new()
	mesh.skin.add_bind(0, Transform3D.IDENTITY)
	skeleton.add_child(mesh)
	mesh.skeleton = NodePath("..")
	return node

func update(flags: int, x: float = 0.0, distance: float = 7.0) -> void:
	check(scene.update_scene(snapshot(flags, x)).is_empty(), "Rigged shadow snapshot rejected")
	scene.camera.position = Vector3(0, distance, distance)
	scene.camera.look_at(Vector3.ZERO)

func frame() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func darker(before: Image, after: Image) -> int:
	var count := 0
	for y in before.get_height():
		for x in before.get_width():
			if before.get_pixel(x, y).get_luminance() - after.get_pixel(x, y).get_luminance() > 0.04: count += 1
	return count

func check_light_type(light: Light3D) -> void:
	viewport.add_child(light)
	light.position = Vector3(-2, 4, 2)
	light.look_at(Vector3.ZERO)
	light.light_energy = 4
	light.shadow_enabled = true
	if light is SpotLight3D: light.spot_range = 12
	if light is AreaLight3D: light.area_range = 12
	update(0)
	var empty := await frame()
	update(2)
	var shadow := await frame()
	var pixels := darker(empty, shadow)
	print("MGS_CHARACTER_SHADOW light=%s pixels=%d" % [light.get_class(), pixels])
	check(pixels > 50, light.get_class() + ": camera-culled character did not cast a shadow")
	update(2, 1.5)
	var moved := await frame()
	check(darker(shadow, moved) > 30 and darker(moved, shadow) > 30, light.get_class() + ": animated shadow did not move")
	light.free()

func run() -> void:
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.use_taa = false
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.size = Vector2i(256, 256)
	viewport.own_world_3d = true
	SceneView.configure_shadows(viewport, root)
	check(viewport.positional_shadow_atlas_size == root.positional_shadow_atlas_size, "Runtime replaced the project shadow atlas size")
	for quadrant in 4:
		check(viewport.get_positional_shadow_atlas_quadrant_subdiv(quadrant) == root.get_positional_shadow_atlas_quadrant_subdiv(quadrant), "Runtime replaced the project shadow allocation")
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(scene)
	scene.add_child(scene.camera)
	scene.camera.environment = Environment.new()
	scene.camera.environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	scene.camera.cull_mask &= ~scene.materials.METADATA_LAYER
	var directory := "user://character-shadow-test"
	DirAccess.make_dir_recursive_absolute(directory)
	var texture := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	texture.fill(Color.WHITE)
	texture.set_pixel(0, 0, Color.TRANSPARENT)
	check(texture.save_png(directory.path_join("0002.png")) == OK, "Cannot write shadow texture fixture")
	check(texture.save_png(directory.path_join("0002.stp.png")) == OK, "Cannot write shadow mask fixture")
	scene.catalog = {ASSET: {"kind": "model", "colorCount": 4},
		"mgs/integral-j/disc1/stage/init/0002.p": {"kind": "texture", "path": "0002.png"}}
	check(scene.materials.initialize(scene.catalog, scene.mods, directory).is_empty(), "Cannot initialize shadow fixture materials")
	scene.templates[ASSET] = model()
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	floor_mesh.mesh.size = Vector2(12, 12)
	viewport.add_child(floor_mesh)
	lamp.position = Vector3(-2, 4, 2)
	lamp.omni_range = 12
	lamp.light_energy = 4
	lamp.shadow_enabled = true
	viewport.add_child(lamp)
	for original in [true, false]:
		scene.mods.stages[""] = {"original_lighting": original}
		if scene.instances.has(1): scene.instances[1].material_stages.clear()
		update(0)
		var empty := await frame()
		update(2)
		var shadow := await frame()
		var pixels := darker(empty, shadow)
		print("MGS_CHARACTER_SHADOW original=%s pixels=%d atlas=%d" % [original, pixels, viewport.positional_shadow_atlas_size])
		check(pixels > 100, "Camera-culled skinned character did not cast a shadow")
		update(2, 1.5)
		var moved := await frame()
		check(darker(shadow, moved) > 50 and darker(moved, shadow) > 50, "Bone animation did not move the character shadow")
		scene.removals.matches[1] = [0]
		update(2)
		check(darker(empty, await frame()) < 10, "Removed original still cast a shadow")
		scene.removals.matches.clear()
	lamp.hide()
	for light in [SpotLight3D.new(), DirectionalLight3D.new(), AreaLight3D.new()]:
		await check_light_type(light)
	lamp.show()
	for index in 12:
		var other := OmniLight3D.new()
		other.position = Vector3((index % 4 - 1.5) * 3, 3, (index / 4 - 1) * 3)
		other.omni_range = 4
		other.light_energy = 0.15
		other.shadow_enabled = true
		viewport.add_child(other)
	for distance in [6.0, 12.0]:
		update(0, 0, distance)
		var empty := await frame()
		update(2, 0, distance)
		check(darker(empty, await frame()) > 30, "Omni shadow vanished with camera distance and competing lights")
	await check_offaxis_model()
	viewport.free()
	print("MGS_CHARACTER_SHADOW_TEST failures=%d" % failures)
	quit(1 if failures else 0)

func check_offaxis_model() -> void:
	var data := snapshot(3, 8)
	for corner in 4:
		data[155 + corner * 4] = 127
		data.encode_float(168 + corner * 16, 0.75)
		data.encode_float(172 + corner * 16, 0.75)
	for original in [true, false]:
		scene.mods.stages[""] = {"original_lighting": original}
		scene.instances[1].material_stages.clear()
		check(scene.update_scene(data).is_empty(), "Off-axis animated model rejected")
		scene.camera.position = Vector3(8, 1, 4)
		scene.camera.look_at(Vector3(8, 1, 0))
		lamp.position = Vector3(8, 2, 3)
		var pixel := (await frame()).get_pixel(128, 128)
		check(pixel.get_luminance() > 0.2, "Model outside native frustum lost its face or live UVs: %s" % pixel)
