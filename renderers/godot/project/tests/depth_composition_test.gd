extends SceneTree

const Renderer = preload("res://renderer.gd")
var renderer := Renderer.new()
var viewport := SubViewport.new()
var camera := Camera3D.new()
var failures: Array[String] = []

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
	finish()

func finish() -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	camera.compositor = null
	RenderingServer.call_on_render_thread(renderer.release.bind(done))

func done() -> void:
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: linear scene depth, front/back composition, world mask and clipped viewport")
	quit(0 if failures.is_empty() else 1)
