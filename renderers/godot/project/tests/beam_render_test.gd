extends SceneTree

const WorldEffects = preload("res://world_effects.gd")
const TEXTURE = "mgs/integral-j/disc1/stage/s02c/1234.p"
var viewport := SubViewport.new()
var effects := WorldEffects.new()
var materials := preload("res://reference_materials.gd").new()
var camera := Camera3D.new()
var heat_view := preload("res://thermal_view.gd").new()
var vision := preload("res://vision_effects.gd").new()
var failures := 0
var fsr2 := "--fsr2" in OS.get_cmdline_user_args()

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func payload(a: Vector3, b: Vector3, start: Color = Color.WHITE, end: Color = Color.WHITE) -> PackedByteArray:
	var bytes := PackedInt32Array([1, 0x1234]).to_byte_array()
	for corner in 4:
		var point := a if corner % 2 == 0 else b
		var color := start if corner % 2 == 0 else end
		bytes.append_array(PackedFloat32Array([point.x, point.y, point.z, 0, 0.5, 0.5, color.r, color.g, color.b, 2 | 8 | 32, 0, 0]).to_byte_array())
	return bytes

func update(data: PackedByteArray) -> void:
	check(effects.update_effects(data, 0, "s02c", materials, camera.transform.affine_inverse()).is_empty(), "Beam update failed")

func frame(thermal: bool = false) -> Image:
	effects.set_thermal_active(thermal)
	for _frame in (12 if fsr2 else 2):
		heat_view.render(camera, Vector2i(Vector2(viewport.size) * viewport.scaling_3d_scale), thermal)
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func brightest(image: Image, center: Vector2i, radius: int = 4) -> Color:
	var result := Color.BLACK
	for y in range(maxi(0, center.y - radius), mini(image.get_height(), center.y + radius + 1)):
		for x in range(maxi(0, center.x - radius), mini(image.get_width(), center.x + radius + 1)):
			var color := image.get_pixel(x, y)
			if color.r + color.g + color.b > result.r + result.g + result.b: result = color
	return result

func run() -> void:
	var folder := "user://beam-render-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	check(image.save_png(folder.path_join("albedo.png")) == OK, "Cannot save beam texture")
	check(image.save_png(folder.path_join("albedo.stp.png")) == OK, "Cannot save beam mask")
	var mods := preload("res://mod_registry.gd").new()
	mods.stages["disc1/s02c"] = {"original_lighting": false}
	check(materials.initialize({TEXTURE: {"path": "albedo.png"}}, mods, folder).is_empty(), "Cannot initialize beam materials")
	materials.current_disc = 1
	viewport.size = Vector2i(320, 224)
	viewport.own_world_3d = true
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2 if fsr2 else Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = 0.75 if fsr2 else 1.0
	root.add_child(viewport)
	viewport.add_child(camera)
	viewport.add_child(effects)
	camera.fov = 90
	camera.near = 0.01
	camera.cull_mask &= ~preload("res://thermal_sources.gd").LAYER
	camera.environment = Environment.new()
	camera.environment.background_mode = Environment.BG_COLOR
	camera.environment.background_color = Color.BLACK
	viewport.add_child(heat_view)
	heat_view.initialize(viewport)
	check(vision.initialize({}, func(message): check(false, message)).is_empty(), "Cannot initialize beam thermal vision")
	vision.thermal_enabled = true
	vision.thermal_world.set("grain_strength", 0.0)
	vision.thermal_world.set("scanline_strength", 0.0)
	vision.thermal_world.call("set_heat_capture", heat_view.capture)
	var compositor := Compositor.new()
	compositor.compositor_effects = [vision.thermal_world]
	camera.compositor = compositor
	update(payload(Vector3(-1, 0, -2), Vector3(1, 0, -2)))
	var batch: Dictionary = effects.batches[TEXTURE]
	for material in [batch.material, batch.depth, batch.heat]: material.set_shader_parameter("beam_width", 5.0)
	await check_geometry(batch)
	await check_reveal(batch)
	await check_thermal(batch)
	update(PackedInt32Array([0]).to_byte_array())
	check(not batch.node.visible, "Retired beam batch still visible")
	camera.compositor = null
	heat_view.camera.compositor = null
	RenderingServer.call_on_render_thread(vision.release)
	RenderingServer.call_on_render_thread(heat_view.capture.release)
	print("MGS_BEAM_RENDER_TEST failures=%d fsr2=%s" % [failures, fsr2])
	quit(1 if failures else 0)

func check_geometry(batch: Dictionary) -> void:
	for endpoint in [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0.8, 0.8, 0)]:
		update(payload(Vector3(0, 0, -2) - endpoint, Vector3(0, 0, -2) + endpoint))
		check(brightest(await frame(), Vector2i(160, 112)).r > 0.6, "Beam vanished with camera-facing direction %s" % endpoint)
	update(payload(Vector3(-1, 0, -2), Vector3(1, 0, -2)))
	check(brightest(await frame(), Vector2i(160, 123), 1).r < 0.02, "Beam width expanded outside its strip")
	viewport.size = Vector2i(400, 224)
	check(brightest(await frame(), Vector2i(200, 112)).r > 0.6, "Widescreen lost beam")
	viewport.size = Vector2i(320, 224)
	camera.position = Vector3(1, 1, 0)
	camera.look_at(Vector3(0, 0, -2))
	check(brightest(await frame(), Vector2i(160, 112)).r > 0.6, "Edited camera lost beam")
	camera.transform = Transform3D.IDENTITY
	update(payload(Vector3(-1, 0, 2), Vector3(1, 0, 2)))
	check(brightest(await frame(), Vector2i(160, 112)).r < 0.02, "Behind-camera beam leaked")
	update(payload(Vector3(-1, 0, -2), Vector3(1, 0, 1)))
	check(brightest(await frame(), Vector2i(160, 112)).r > 0.4, "Near-plane crossing beam vanished")
	update(payload(Vector3(0, 0, -2), Vector3(0, 0, -2)))
	check(brightest(await frame(), Vector2i(160, 112)).r < 0.02, "Zero-length segment produced a streak")
	check(effects.batches[TEXTURE].node == batch.node, "Beam mesh rebuilt per frame")

func check_reveal(batch: Dictionary) -> void:
	update(payload(Vector3(-1, 0, -2), Vector3(1, 0, -2), Color.BLACK, Color.BLACK))
	check(brightest(await frame(), Vector2i(160, 112)).r < 0.02, "Hidden native beam was revealed")
	update(payload(Vector3(-1, 0, -2), Vector3(1, 0, -2), Color.RED, Color.BLACK))
	var cigarette := await frame()
	check(brightest(cigarette, Vector2i(116, 112)).r > brightest(cigarette, Vector2i(204, 112)).r * 2, "Cigarette endpoint fade was lost")
	check(brightest(cigarette, Vector2i(116, 112)).g < 0.02, "Cigarette reveal lost red shade")
	for material in [batch.material, batch.depth, batch.heat]: material.set_shader_parameter("effect_tint", Color.GREEN)
	update(payload(Vector3(-1, 0, -2), Vector3(1, 0, -2)))
	var styled := brightest(await frame(), Vector2i(160, 112))
	check(styled.g > 0.6 and styled.r < 0.02, "Edited beam tint ignored")
	for material in [batch.material, batch.depth, batch.heat]: material.set_shader_parameter("effect_tint", Color.WHITE)

func check_thermal(batch: Dictionary) -> void:
	vision.update({"vision_mode": 2})
	var hot := brightest(await frame(true), Vector2i(160, 112))
	check(hot.g > 0.5 and hot.r > 0.5, "IR beam remained cold: %s" % hot)
	var wall := MeshInstance3D.new()
	wall.mesh = QuadMesh.new()
	wall.mesh.size = Vector2(0.4, 0.8)
	wall.position.z = -1
	viewport.add_child(wall)
	check(brightest(await frame(true), Vector2i(160, 112)).g < 0.2, "Beam heat leaked through wall")
	wall.free()
	batch.heat.set_shader_parameter("beam_heat", 0.0)
	check(brightest(await frame(true), Vector2i(160, 112)).g < 0.3, "Edited beam heat ignored")
	batch.heat.set_shader_parameter("beam_heat", 1.0)
	update(payload(Vector3(-1, 0, -2), Vector3(1, 0, -2), Color.BLACK, Color.BLACK))
	check(brightest(await frame(true), Vector2i(160, 112)).g < 0.2, "Invisible beam retained heat")
	vision.update({"vision_mode": 0})
	await frame()
	check(not batch.heat_node.visible and heat_view.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Beam heat pass stayed active")
