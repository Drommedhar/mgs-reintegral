extends SceneTree

var viewport := SubViewport.new()
var heat_view := preload("res://thermal_view.gd").new()
var background := preload("res://world_background.gd").new()
var sources := preload("res://thermal_sources.gd").new()
var vision := preload("res://vision_effects.gd").new()
var camera := Camera3D.new()
var empty := ShaderMaterial.new()
var native_mesh: MeshInstance3D
var custom_mesh: MeshInstance3D
var skeleton := Skeleton3D.new()
var failures := 0
var fsr2 := "--fsr2" in OS.get_cmdline_user_args()

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func quad(position: Vector3, size: Vector2, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.position = position
	mesh.mesh = QuadMesh.new()
	mesh.mesh.size = size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	mesh.material_override = material
	viewport.add_child(mesh)
	return mesh

func frame(active: bool) -> Image:
	sources.synchronize({1: {"thermal": true, "meshes": [native_mesh]}}, active, empty)
	heat_view.render(camera, Vector2i(Vector2(viewport.size) * viewport.scaling_3d_scale), active)
	background.render(camera, viewport.size)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func run() -> void:
	viewport.size = Vector2i(128, 128)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2 if fsr2 else Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = 0.75 if fsr2 else 1.0
	root.add_child(viewport)
	viewport.add_child(camera)
	camera.cull_mask &= ~sources.LAYER
	camera.environment = Environment.new()
	camera.environment.background_mode = Environment.BG_COLOR
	camera.environment.background_color = Color(0.1, 0.2, 0.5)
	root.add_child(background)
	background.initialize(viewport)
	viewport.add_child(heat_view)
	heat_view.initialize(viewport)
	check(vision.initialize({}, func(message): check(false, message)).is_empty(), "Cannot initialize thermal compositor")
	vision.thermal_enabled = true
	vision.thermal_world.set("grain_strength", 0.0)
	vision.thermal_world.set("scanline_strength", 0.0)
	vision.thermal_world.call("set_heat_capture", heat_view.capture)
	var compositor := Compositor.new()
	compositor.compositor_effects = [vision.world, vision.thermal_world]
	camera.compositor = compositor
	var background_compositor := Compositor.new()
	background_compositor.compositor_effects = [vision.thermal_background]
	background.camera.compositor = background_compositor
	native_mesh = quad(Vector3(-0.5, 0, -2), Vector2(0.8, 1.5), Color(0.01, 0.02, 0.3))
	skeleton.name = "ThermalRig"
	skeleton.add_bone("body")
	viewport.add_child(skeleton)
	var arrays: Array = native_mesh.mesh.surface_get_arrays(0)
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	for _vertex in arrays[Mesh.ARRAY_VERTEX].size():
		bones.append_array([0, 0, 0, 0])
		weights.append_array([1, 0, 0, 0])
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	var skinned := ArrayMesh.new()
	var shape: Array = []
	shape.resize(Mesh.ARRAY_MAX)
	var shifted: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX].duplicate()
	for index in shifted.size(): shifted[index] += Vector3.RIGHT
	shape[Mesh.ARRAY_VERTEX] = shifted
	shape[Mesh.ARRAY_NORMAL] = arrays[Mesh.ARRAY_NORMAL]
	shape[Mesh.ARRAY_TANGENT] = arrays[Mesh.ARRAY_TANGENT]
	skinned.add_blend_shape("shift_right")
	skinned.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [shape])
	native_mesh.mesh = skinned
	native_mesh.skin = Skin.new()
	native_mesh.skin.add_bind(0, Transform3D.IDENTITY)
	native_mesh.skeleton = NodePath("../ThermalRig")
	custom_mesh = quad(Vector3(0.5, 0, -2), Vector2(0.8, 1.5), Color(0.01, 0.02, 0.3))
	var wall := quad(Vector3(-0.375, 0, -1.5), Vector2(0.24, 0.5), Color(0.05, 0.1, 0.6))
	check(sources.register(custom_mesh, 0.8).is_empty(), "Cannot register custom mesh heat")
	var original := await frame(false)
	vision.update({"vision_mode": 2})
	var filtered := await frame(true)
	if fsr2:
		for _index in 12: filtered = await frame(true)
	var warm := filtered.get_pixel(43, 40)
	var blocked := filtered.get_pixel(43, 64)
	var custom := filtered.get_pixel(85, 64)
	check(warm.g > 0.4 and warm.r > 0.5, "Native IR heat is missing: %s" % warm)
	check(custom.g > 0.4, "Authored heat is missing: %s" % custom)
	check(blocked.g < 0.2 and blocked.r > blocked.b, "Wall did not occlude heat: %s" % blocked)
	var sky := background.get_texture().get_image().get_pixel(16, 16)
	check(sky.r > sky.b * 2 and sky.g < 0.2, "Empty background escaped thermal filtering: %s" % sky)
	if not fsr2: check(absf(blocked.a - original.get_pixel(43, 64).a) < 0.01, "Thermal effect changed alpha")
	wall.hide()
	filtered = await frame(true)
	if fsr2:
		for _index in 12: filtered = await frame(true)
	check(filtered.get_pixel(43, 64).g > 0.4, "Heat did not appear when wall was hidden")
	custom_mesh.position.x = 1.0
	filtered = await frame(true)
	if fsr2:
		for _index in 12: filtered = await frame(true)
	check(filtered.get_pixel(107, 64).g > 0.4, "Moved source heat did not follow geometry")
	skeleton.set_bone_pose_position(0, Vector3(-0.5, 0, 0))
	filtered = await frame(true)
	if fsr2:
		for _index in 12: filtered = await frame(true)
	check(filtered.get_pixel(22, 64).g > 0.4, "Skinned heat did not follow the shared bone pose")
	skeleton.set_bone_pose_position(0, Vector3.ZERO)
	custom_mesh.hide()
	native_mesh.set_blend_shape_value(0, 1.0)
	filtered = await frame(true)
	if fsr2:
		for _index in 12: filtered = await frame(true)
	check(filtered.get_pixel(85, 64).g > 0.4 and filtered.get_pixel(43, 64).g < 0.2, "Heat silhouette did not follow the blend shape")
	native_mesh.set_blend_shape_value(0, 0.0)
	filtered = await frame(true)
	if fsr2:
		for _index in 12: filtered = await frame(true)
	check(filtered.get_pixel(43, 64).g > 0.4 and filtered.get_pixel(85, 64).g < 0.2, "Heat silhouette retained a previous blend shape")
	vision.thermal_world.set("hot_tint", Color(0.1, 0.2, 1.0))
	vision.update({"vision_mode": 2})
	filtered = await frame(true)
	if fsr2:
		for _index in 12: filtered = await frame(true)
	check(filtered.get_pixel(43, 64).b > filtered.get_pixel(43, 64).r * 2, "Edited hot tint was ignored")
	vision.update({"vision_mode": 0})
	var restored := await frame(false)
	if fsr2:
		for _index in 12: restored = await frame(false)
	check(restored.get_pixel(43, 64).b > restored.get_pixel(43, 64).r * 2, "Thermal removal did not restore original shading")
	check(sources.copies.is_empty() and heat_view.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Heat pass remained active without goggles")
	camera.compositor = null
	heat_view.camera.compositor = null
	background.camera.compositor = null
	RenderingServer.call_on_render_thread(vision.release)
	RenderingServer.call_on_render_thread(heat_view.capture.release)
	print("MGS_THERMAL_VISION_RENDER_TEST failures=%d fsr2=%s" % [failures, fsr2])
	quit(1 if failures else 0)
