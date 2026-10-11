extends SceneTree

const Renderer = preload("res://renderer.gd")
var renderer := Renderer.new()
var viewport := SubViewport.new()
var camera := Camera3D.new()
var failures: Array[String] = []
var metadata_viewport := SubViewport.new()
var metadata_camera := Camera3D.new()
var meshes: Array[MeshInstance3D] = []
var packet_texture: ImageTexture
var shade_texture: ImageTexture
var background := preload("res://world_background.gd").new()

func _initialize() -> void:
	call_deferred("run")

func quad(color: Color, position: Vector3, extent: float) -> void:
	var node := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE * extent
	node.mesh = mesh
	node.position = position
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	node.material_override = material
	viewport.add_child(node)
	meshes.append(node)

func run() -> void:
	viewport.size = Vector2i(64, 64)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(camera)
	camera.fov = 90
	camera.near = 0.01
	camera.far = 250
	var compositor := Compositor.new()
	compositor.compositor_effects = [renderer.depth_capture]
	camera.compositor = compositor
	quad(Color.RED, Vector3(-0.7, 0, -2), 0.8)
	quad(Color.BLUE, Vector3(1.4, 0, -4), 1.6)
	renderer.world_texture = viewport.get_texture().get_rid()
	RenderingServer.call_on_render_thread(renderer.initialize.bind(ready))

func ready(_target: RID, error: String) -> void:
	if not error.is_empty():
		failures.append(error)
		finish()
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	RenderingServer.call_on_render_thread(check_composition)

func payload(values: Array) -> PackedByteArray:
	if values.size() == 12: values = values + [0]
	return PackedInt32Array(values).to_byte_array()

func check_composition() -> void:
	var rd := RenderingServer.get_rendering_device()
	var depths := rd.texture_get_data(renderer.depth_capture.texture, 0)
	for sample in [[21, 2000.0], [43, 4000.0]]:
		var measured := depths.decode_float((32 * 64 + sample[0]) * 4)
		if absf(measured - sample[1]) > 1:
			failures.append("Linear scene depth %s, expected %s" % [measured, sample[1]])
	var commands := [
		[8, payload([0, 0, 64, 64, 0, 0, 0])],
		[10, payload([0, 0, 64, 64, 0, 0, 3000, 65536, 0, 0, 64, 64])],
		[8, payload([0, 0, 64, 64, 0, 248, 0])],
		[10, payload([0, 0, 64, 64, 1, 0, 0, 3000, 0, 0, 64, 64])]]
	renderer.execute(commands, 5, payload([0, 32, 64, 1]), checked)

func checked(_operation: int, _payload: PackedByteArray, pixels: PackedByteArray, error: String) -> void:
	if not error.is_empty(): failures.append(error)
	else:
		if pixels.slice(21 * 4, 22 * 4) != PackedByteArray([255, 0, 0, 255]):
			failures.append("Near mesh must cover the intermediate effect and set its mask")
		if pixels.slice(43 * 4, 44 * 4) != PackedByteArray([0, 255, 0, 0]):
			failures.append("Far mesh must stay behind the intermediate effect")
	var commands := [
		[8, payload([0, 0, 64, 64, 0, 248, 0])],
		[10, payload([16, 16, 32, 32, 0, 0, 0, 65536, 0, 0, 64, 64])]]
	RenderingServer.call_on_render_thread(renderer.execute.bind(commands, 5, payload([0, 32, 64, 1]), checked_clip))

func checked_clip(_operation: int, _payload: PackedByteArray, pixels: PackedByteArray, error: String) -> void:
	if not error.is_empty(): failures.append(error)
	else:
		for sample in [[21, PackedByteArray([255, 0, 0, 0])], [43, PackedByteArray([0, 0, 255, 0])], [30, PackedByteArray([0, 255, 0, 0])]]:
			if pixels.slice(sample[0] * 4, (sample[0] + 1) * 4) != sample[1]:
				failures.append("Scissor must crop the world without rescaling its projection: pixel %d" % sample[0])
	await check_metadata()

func image_texture(color: Color, format: Image.Format = Image.FORMAT_RGBA8) -> ImageTexture:
	var image := Image.create(1, 1, false, format)
	image.fill(color)
	return ImageTexture.create_from_image(image)

func check_metadata() -> void:
	metadata_viewport.size = viewport.size
	metadata_viewport.transparent_bg = true
	metadata_viewport.world_3d = viewport.find_world_3d()
	metadata_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(metadata_viewport)
	metadata_viewport.add_child(metadata_camera)
	metadata_camera.fov = camera.fov
	metadata_camera.near = camera.near
	metadata_camera.far = camera.far
	metadata_camera.cull_mask = 1 << 19
	metadata_camera.environment = Environment.new()
	camera.cull_mask &= ~(1 << 19)
	var compositor := Compositor.new()
	compositor.compositor_effects = [renderer.metadata_depth]
	metadata_camera.compositor = compositor
	for index in meshes.size():
		var copy := meshes[index].duplicate() as MeshInstance3D
		copy.layers = 1 << 19
		var material := ShaderMaterial.new()
		material.shader = preload("res://reference_metadata.gdshader")
		material.set_shader_parameter("albedo_texture", image_texture(Color.WHITE))
		material.set_shader_parameter("mask_texture", image_texture(Color.WHITE))
		material.set_shader_parameter("shade_texture", image_texture(Color(0.5, 0.5, 0.5, 1)))
		material.set_shader_parameter("packet_texture", image_texture(Color(0.5, 0.5, 6000 if index == 0 else 1000, 0), Image.FORMAT_RGBAF))
		copy.material_override = material
		viewport.add_child(copy)
	renderer.metadata_texture = metadata_viewport.get_texture().get_rid()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var commands := [
		[8, payload([0, 0, 64, 64, 0, 0, 0])],
		[10, payload([0, 0, 64, 64, 0, 0, 3000, 65536, 0, 0, 64, 64])],
		[8, payload([0, 0, 64, 64, 0, 248, 0])],
		[10, payload([0, 0, 64, 64, 0, 0, 0, 3000, 0, 0, 64, 64])]]
	RenderingServer.call_on_render_thread(renderer.execute.bind(commands, 5, payload([0, 32, 64, 1]), checked_metadata))

func checked_metadata(_operation: int, _payload: PackedByteArray, pixels: PackedByteArray, error: String) -> void:
	if not error.is_empty(): failures.append(error)
	else:
		if pixels.slice(21 * 4, 22 * 4) != PackedByteArray([0, 255, 0, 0]):
			failures.append("Original ordering depth must put the near mesh behind the effect")
		if pixels.slice(43 * 4, 44 * 4) != PackedByteArray([0, 0, 255, 255]):
			failures.append("Original ordering depth and STP must put the far mesh over the effect with a mask")
	var material := ShaderMaterial.new()
	material.shader = preload("res://reference.gdshader")
	var image := Image.create(2, 1, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, Color.RED)
	image.set_pixel(1, 0, Color.BLUE)
	material.set_shader_parameter("albedo_texture", ImageTexture.create_from_image(image))
	shade_texture = image_texture(Color8(128, 128, 128, 255))
	packet_texture = image_texture(Color(0.75, 0.5, 6000, 0), Image.FORMAT_RGBAF)
	material.set_shader_parameter("shade_texture", shade_texture)
	material.set_shader_parameter("packet_texture", packet_texture)
	meshes[0].material_override = material
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	RenderingServer.call_on_render_thread(renderer.execute.bind([
		[8, payload([0, 0, 64, 64, 0, 248, 0])],
		[10, payload([0, 0, 64, 64, 0, 0, 0, 65536, 0, 0, 64, 64])]],
		5, payload([21, 32, 1, 1]), checked_live_uv))

func checked_live_uv(_operation: int, _payload: PackedByteArray, pixels: PackedByteArray, error: String) -> void:
	if not error.is_empty(): failures.append(error)
	elif pixels != PackedByteArray([0, 0, 255, 255]): failures.append("Packet UV did not select the blue texel: " + str(pixels))
	RenderingServer.call_on_render_thread(renderer.execute.bind([
		[8, payload([0, 0, 64, 64, 0, 248, 0])],
		[10, payload([0, 0, 64, 64, 0, 0, 0, 65536, 0, 0, 64, 64, 1])]],
		5, payload([20, 32, 2, 1]), checked_dither))

func checked_dither(_operation: int, _payload: PackedByteArray, pixels: PackedByteArray, error: String) -> void:
	if not error.is_empty(): failures.append(error)
	elif pixels != PackedByteArray([0, 0, 247, 255, 0, 0, 255, 255]):
		failures.append("WORLD dither flag did not preserve native modulation/quantization: " + str(pixels))
	quad(Color.YELLOW, Vector3(-0.35, 0, -1), 0.4)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	RenderingServer.call_on_render_thread(renderer.execute.bind([
		[8, payload([0, 0, 64, 64, 0, 248, 0])],
		[10, payload([0, 0, 64, 64, 0, 0, 0, 3000, 0, 0, 64, 64])]],
		5, payload([21, 32, 1, 1]), checked_custom_geometry))

func checked_custom_geometry(_operation: int, _payload: PackedByteArray, pixels: PackedByteArray, error: String) -> void:
	if not error.is_empty(): failures.append(error)
	elif pixels != PackedByteArray([255, 255, 0, 0]): failures.append("Custom foreground geometry inherited background ordering/mask metadata")
	meshes.pop_back().queue_free()
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	shade_texture.update(image)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	RenderingServer.call_on_render_thread(renderer.execute.bind([
		[8, payload([0, 0, 64, 64, 0, 248, 0])],
		[10, payload([0, 0, 64, 64, 0, 0, 0, 65536, 0, 0, 64, 64])]],
		5, payload([21, 32, 1, 1]), checked_hidden_face))

func checked_hidden_face(_operation: int, _payload: PackedByteArray, pixels: PackedByteArray, error: String) -> void:
	if not error.is_empty(): failures.append(error)
	elif pixels != PackedByteArray([0, 255, 0, 0]): failures.append("Hidden native face still contributed world pixels")
	await check_background()

func check_background() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.BLACK
	environment.fog_enabled = true
	environment.fog_density = 1.0
	environment.fog_light_color = Color(0.2, 0.6, 0.8)
	camera.environment = environment
	root.add_child(background)
	background.initialize(viewport)
	background.render(camera, viewport.size)
	renderer.background_texture = background.get_texture().get_rid()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var commands := [
		[8, payload([0, 0, 64, 64, 0, 0, 0])],
		[10, payload([0, 0, 64, 64, 0, 0, 65536, 65537, 0, 0, 64, 64])],
		[8, payload([0, 0, 8, 64, 248, 0, 0])]]
	RenderingServer.call_on_render_thread(renderer.execute.bind(commands, 5, payload([0, 32, 64, 1]), checked_background))

func checked_background(_operation: int, _payload: PackedByteArray, pixels: PackedByteArray, error: String) -> void:
	if not error.is_empty(): failures.append(error)
	elif pixels[32 * 4 + 1] < 50 or pixels[32 * 4 + 2] < 50:
		failures.append("Empty space must receive environment fog: " + str(pixels.slice(128, 132)))
	if pixels.slice(0, 4) != PackedByteArray([255, 0, 0, 0]):
		failures.append("Native foreground commands must cover the fog background")
	var environment := camera.environment
	environment.fog_enabled = false
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.3
	environment.volumetric_fog_length = 12
	environment.volumetric_fog_ambient_inject = 0.0
	var light := OmniLight3D.new()
	light.light_color = Color.RED
	light.light_energy = 10
	light.omni_range = 10
	light.position = Vector3(0, 0, -2)
	viewport.add_child(light)
	for frame in 8:
		background.render(camera, viewport.size)
		await RenderingServer.frame_post_draw
	var image := background.get_texture().get_image()
	var color := image.get_pixel(image.get_width() / 2, image.get_height() / 2)
	if color.r < 0.1 or color.r < color.g * 2:
		failures.append("Background volumetric fog must receive scene lights: " + str(color))
	finish()

func finish() -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	metadata_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	camera.compositor = null
	metadata_camera.compositor = null
	RenderingServer.call_on_render_thread(renderer.release.bind(done))

func done() -> void:
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: depth, clipping, packet ordering, STP, dithering, live UVs, custom geometry and face visibility")
	quit(0 if failures.is_empty() else 1)
