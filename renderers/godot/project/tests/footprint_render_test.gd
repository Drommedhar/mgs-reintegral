extends SceneTree

const WorldEffects = preload("res://world_effects.gd")
const ReferenceMaterials = preload("res://reference_materials.gd")
const ModRegistry = preload("res://mod_registry.gd")
const IDENTITY = "mgs/integral-j/disc1/stage/s00a/dc55.p"
var viewport := SubViewport.new()
var effects := WorldEffects.new()
var materials := ReferenceMaterials.new()
var failures := 0

func check(value: bool, message: String) -> void:
	if value: return
	push_error(message)
	failures += 1

func payload(shade: float, count: int = 1) -> PackedByteArray:
	var data := PackedInt32Array([count]).to_byte_array()
	for quad in count:
		data.append_array(PackedInt32Array([0xdc55]).to_byte_array())
		for corner in 4:
			var u := float(corner & 1)
			var v := float((corner >> 1) & 1)
			data.append_array(PackedFloat32Array([u * 2 - 1, 1 - v * 2, -2, 0.002,
				u, v, shade, shade, shade, 3 | 128, 0, 0]).to_byte_array())
	return data

func frame() -> Image:
	for tick in 12: await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func update(shade: float, count: int = 1) -> Image:
	check(effects.update_effects(payload(shade, count), 0, "s00a", materials).is_empty(), "Footprint payload rejected")
	return await frame()

func _initialize() -> void:
	create_timer(45).timeout.connect(quit.bind(1))
	run.call_deferred()

func run() -> void:
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	var folder := "user://footprint-render-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	for y in 8:
		for x in 4: image.set_pixel(x, y, Color.TRANSPARENT)
	check(image.save_png(folder.path_join("print.png")) == OK, "Cannot save footprint fixture")
	image.fill(Color.WHITE)
	check(image.save_png(folder.path_join("print.stp.png")) == OK, "Cannot save footprint mask")
	check(materials.initialize({IDENTITY: {"path": "print.png"}}, ModRegistry.new(), folder).is_empty(), "Cannot initialize footprints")
	materials.current_disc = 1
	viewport.size = Vector2i(128, 128)
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.use_taa = false
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new()
	camera.fov = 90
	camera.environment = Environment.new()
	camera.environment.background_mode = Environment.BG_COLOR
	camera.environment.background_color = Color.BLACK
	viewport.add_child(camera)
	viewport.add_child(effects)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = QuadMesh.new()
	floor_mesh.position.z = -2
	var floor_material := StandardMaterial3D.new()
	floor_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_material.albedo_color = Color(0.8, 0.8, 0.8)
	floor_mesh.material_override = floor_material
	viewport.add_child(floor_mesh)
	var clear := await update(0, 0)
	var full := await update(0.375)
	var initial_node: Node = effects.batches[IDENTITY].node
	check(full.get_pixel(76, 64).r < clear.get_pixel(76, 64).r - 0.08, "Wet footprint did not darken its coplanar floor")
	check(absf(full.get_pixel(52, 64).r - clear.get_pixel(52, 64).r) < 0.01, "Transparent footprint pixels darkened the floor")
	var faded := await update(0.1)
	check(faded.get_pixel(76, 64).r > full.get_pixel(76, 64).r + 0.03, "Native footprint fade was lost")
	var overlap := await update(0.375, 2)
	check(overlap.get_pixel(76, 64).r < full.get_pixel(76, 64).r - 0.03, "Overlapping footprints failed to accumulate")
	floor_mesh.position.z = -1.5
	var blocked := await update(0.375)
	check(absf(blocked.get_pixel(76, 64).r - clear.get_pixel(76, 64).r) < 0.01, "Footprint leaked through foreground geometry")
	floor_mesh.position.z = -2
	var zero := await update(0)
	check(absf(zero.get_pixel(76, 64).r - clear.get_pixel(76, 64).r) < 0.01, "Fully faded footprint still changed the floor")
	var expired := await update(0, 0)
	check(absf(expired.get_pixel(76, 64).r - clear.get_pixel(76, 64).r) < 0.01, "Expired footprint remained visible")
	check(effects.batches[IDENTITY].node == initial_node, "Footprint batch rebuilt during its native lifetime")
	print("Footprint GPU: failures=%d clear=%.3f full=%.3f faded=%.3f overlap=%.3f" % [failures, clear.get_pixel(76, 64).r, full.get_pixel(76, 64).r, faded.get_pixel(76, 64).r, overlap.get_pixel(76, 64).r])
	viewport.free()
	for file in ["print.png", "print.stp.png"]: DirAccess.remove_absolute(folder.path_join(file))
	DirAccess.remove_absolute(folder)
	quit(1 if failures else 0)
