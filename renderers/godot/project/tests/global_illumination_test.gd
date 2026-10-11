extends SceneTree

const SHADER = preload("res://reference_lit.gdshader")
var failures := 0
var viewport := SubViewport.new()

func check(condition: bool, message: String) -> void:
	if condition: return
	push_error(message)
	failures += 1

func texture(color: Color) -> ImageTexture:
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)

func box(position: Vector3, size: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = BoxMesh.new()
	node.mesh.size = size
	node.position = position
	node.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	viewport.add_child(node)
	return node

func frame(count: int) -> Image:
	for _index in count: await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	viewport.size = Vector2i(160, 160)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.position = Vector3(0, 2.5, 6)
	camera.look_at(Vector3(0, 1, 0))
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.BLACK
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	environment.ssil_enabled = false
	environment.sdfgi_read_sky_light = false
	environment.sdfgi_min_cell_size = 0.1
	environment.sdfgi_cascades = 4
	environment.sdfgi_use_occlusion = true
	camera.environment = environment
	box(Vector3(0, -0.25, 0), Vector3(8, 0.5, 8))
	box(Vector3(0, 2, -2.25), Vector3(8, 4, 0.5))
	var receiver := box(Vector3(1.5, 0.5, 0), Vector3.ONE)
	receiver.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var source := box(Vector3(0, 1, -1.8), Vector3(1, 1, 0.25))
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("albedo_texture", texture(Color.BLACK))
	material.set_shader_parameter("shade_texture", texture(Color.TRANSPARENT))
	material.set_shader_parameter("packet_texture", texture(Color.BLACK))
	material.set_shader_parameter("has_emission", true)
	material.set_shader_parameter("emission_texture", texture(Color.GREEN))
	material.set_shader_parameter("emission_energy", 5.0)
	source.material_override = material
	var direct := await frame(8)
	environment.sdfgi_enabled = true
	var bounced := await frame(160)
	var green_pixels := 0
	for y in 160:
		for x in 160:
			var color := bounced.get_pixel(x, y)
			if color.g - direct.get_pixel(x, y).g > 0.03 and color.g > color.r * 1.2: green_pixels += 1
	check(green_pixels > 100, "Reference shader did not contribute SDFGI color bounce: %d pixels" % green_pixels)
	var sample := Vector2i(camera.unproject_position(receiver.position + Vector3(0, 0, 0.51)))
	check(bounced.get_pixelv(sample).g > direct.get_pixelv(sample).g + 0.01, "Dynamic actor did not receive SDFGI")
	print("MGS_SDFGI pixels=%d actor=%s" % [green_pixels, bounced.get_pixelv(sample)])
	viewport.free()
	print("MGS_GLOBAL_ILLUMINATION_TEST failures=%d" % failures)
	quit(1 if failures else 0)
