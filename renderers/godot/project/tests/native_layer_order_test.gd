extends SceneTree

var failures := 0
var viewport := SubViewport.new()
var camera := Camera3D.new()

func check(value: bool, message: String) -> void:
	if value: return
	failures += 1
	push_error(message)

func texture(color: Color) -> ImageTexture:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBAF)
	image.fill(color)
	return ImageTexture.create_from_image(image)

func layer(color: Color, bias: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = QuadMesh.new()
	node.mesh.size = Vector2(12, 12)
	node.position.z = -20
	var material := ShaderMaterial.new()
	material.shader = preload("res://reference.gdshader")
	material.set_shader_parameter("albedo_texture", texture(color))
	material.set_shader_parameter("shade_texture", texture(Color(128.0 / 255, 128.0 / 255, 128.0 / 255, 1)))
	material.set_shader_parameter("packet_texture", texture(Color(0.5, 0.5, 1000, 0)))
	material.set_shader_parameter("quantize_color", false)
	node.material_override = material
	viewport.add_child(node)
	node.set_instance_shader_parameter("native_depth_bias", bias)
	return node

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	viewport.size = Vector2i(96, 96)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(camera)
	camera.near = 0.01
	camera.far = 250
	var near_layer := layer(Color.GREEN, 0)
	var far_layer := layer(Color.RED, -0.001)
	for position in [Vector3.ZERO, Vector3(2, 1, 1), Vector3(-2, -1, -1)]:
		camera.position = position
		camera.look_at(Vector3(0, 0, -20))
		for tick in 3: await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		var incorrect := 0
		for y in range(36, 60):
			for x in range(36, 60):
				var pixel := image.get_pixel(x, y)
				if pixel.g < 0.9 or pixel.r > 0.1: incorrect += 1
		check(incorrect == 0, "Coplanar native map layers lost their order: %d pixels at %s" % [incorrect, position])
	far_layer.position.z = -19.9
	for tick in 3: await RenderingServer.frame_post_draw
	check(viewport.get_texture().get_image().get_pixel(48, 48).r > 0.9, "Native layer bias overrode real foreground occlusion")
	near_layer.free()
	viewport.free()
	print("MGS_NATIVE_LAYER_ORDER_TEST failures=%d" % failures)
	quit(1 if failures else 0)
