extends SceneTree

var viewport := SubViewport.new()
var camera := Camera3D.new()
var material := ShaderMaterial.new()
var failures := 0

func check(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)

func _initialize() -> void:
	run.call_deferred()

func measure(shader: Shader, texture: Texture2D) -> float:
	material.shader = shader
	material.set_shader_parameter("albedo_texture", texture)
	var shade := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	shade.fill(Color(0, 0, 0, 0))
	material.set_shader_parameter("shade_texture", ImageTexture.create_from_image(shade))
	var previous := PackedByteArray()
	var delta := 0.0
	var count := 0
	for tick in 64:
		camera.position.x = tick * 0.003
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		if tick < 16: continue
		var image := viewport.get_texture().get_image().get_region(Rect2i(40, 110, 240, 80))
		image.convert(Image.FORMAT_RGB8)
		var data := image.get_data()
		if not previous.is_empty():
			for index in range(0, data.size(), 3):
				delta += absf(float(data[index]) - previous[index])
				count += 1
		previous = data
	return delta / max(count, 1)

func run() -> void:
	viewport.size = Vector2i(320, 224)
	viewport.own_world_3d = true
	root.add_child(viewport)
	viewport.add_child(camera)
	camera.position = Vector3(0, 1, 2)
	camera.look_at(Vector3(0, 0, -10))
	camera.environment = Environment.new()
	camera.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	camera.environment.ambient_light_color = Color.WHITE
	camera.environment.ambient_light_energy = 1
	var mesh := MeshInstance3D.new()
	mesh.mesh = PlaneMesh.new()
	mesh.mesh.size = Vector2(40, 40)
	mesh.position.z = -18
	mesh.material_override = material
	viewport.add_child(mesh)
	var image := Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
	for y in 1024:
		for x in 1024: image.set_pixel(x, y, Color.WHITE if (x + y) % 8 < 4 else Color.BLACK)
	var path := "user://reference-minification-%d.png" % Time.get_ticks_usec()
	image.save_png(path)
	var resources := preload("res://reference_materials.gd").new()
	var registry := preload("res://mod_registry.gd").new()
	check(resources.initialize({"fixture":{"path":path}}, registry, "").is_empty(), "Material initialization failed")
	var filtered := resources.texture_for("fixture", false)
	check(filtered.get_image().has_mipmaps(), "Reference material lacks mipmaps")
	var shader: Shader = preload("res://reference_lit.gdshader")
	var old_shader := Shader.new()
	old_shader.code = shader.code.replace('#include "reference_packet.gdshaderinc"', FileAccess.get_file_as_string("res://reference_packet.gdshaderinc").replace("filter_linear_mipmap_anisotropic", "filter_nearest"))
	var baseline := await measure(old_shader, ImageTexture.create_from_image(image))
	var stable := await measure(shader, filtered)
	check(baseline > 1.0 and stable < baseline * 0.7, "Reference texture temporal aliasing was not reduced")
	print("MGS_REFERENCE_TEXTURE_FILTER_TEST baseline=%f filtered=%f failures=%d" % [baseline, stable, failures])
	viewport.free()
	quit(1 if failures else 0)
