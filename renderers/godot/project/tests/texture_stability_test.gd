extends SceneTree

var viewport := SubViewport.new()
var camera := Camera3D.new()
var material := StandardMaterial3D.new()

func _initialize() -> void:
	run.call_deferred()

func measure(bias: float, filter: int) -> float:
	viewport.texture_mipmap_bias = bias
	material.texture_filter = filter
	var previous := PackedByteArray()
	var delta := 0.0
	var samples := 0
	for frame in 96:
		camera.position.x = frame * 0.001
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		if frame < 48: continue
		var img := viewport.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		var pixels := img.get_region(Rect2i(20, 100, 280, 100)).get_data()
		if not previous.is_empty():
			for index in range(0, pixels.size(), 3):
				delta += absf(float(pixels[index]) - previous[index])
				samples += 1
		previous = pixels
	print("MGS_TEXTURE_STABILITY_SAMPLE bias=%s filter=%d motion_delta=%f" % [bias, filter, delta / samples])
	return delta / samples

func run() -> void:
	preload("res://scene_view.gd").configure_rendering(viewport, root)
	viewport.size = Vector2i(320, 224)
	viewport.own_world_3d = true
	root.add_child(viewport)
	viewport.add_child(camera)
	camera.position = Vector3(0, 1, 2)
	camera.look_at(Vector3(0, 0, -10))
	var mesh := MeshInstance3D.new()
	mesh.mesh = PlaneMesh.new()
	mesh.mesh.size = Vector2(40, 40)
	mesh.position.z = -18
	var img := Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
	for y in 1024:
		for x in 1024: img.set_pixel(x, y, Color.WHITE if (x + y) % 8 < 4 else Color.BLACK)
	img.generate_mipmaps()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = ImageTexture.create_from_image(img)
	material.uv1_scale = Vector3(1, 1, 1)
	mesh.material_override = material
	viewport.add_child(mesh)
	var configured_bias := viewport.texture_mipmap_bias
	var baseline := await measure(0.0, BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)
	var filtered := await measure(configured_bias, BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)
	var success := filtered < baseline * 0.92 and viewport.scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR2 and viewport.scaling_3d_scale == 1.0
	print("MGS_TEXTURE_STABILITY_TEST baseline=%f filtered=%f failures=%d" % [baseline, filtered, 0 if success else 1])
	viewport.queue_free()
	await process_frame
	quit(0 if success else 1)
