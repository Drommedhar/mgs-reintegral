extends RefCounted

const WorldEffects = preload("res://world_effects.gd")

static func texture(color: Color) -> ImageTexture:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBAF)
	image.fill(color)
	return ImageTexture.create_from_image(image)

static func add_mesh(parent: Node3D, source: MeshInstance3D, shader: Shader, white: Texture2D, packet: Texture2D) -> void:
	var skeleton := Skeleton3D.new()
	skeleton.add_bone("warmup")
	parent.add_child(skeleton)
	var node := MeshInstance3D.new()
	node.mesh = source.mesh
	var skin := Skin.new()
	for _bind in source.skin.get_bind_count(): skin.add_bind(0, Transform3D.IDENTITY)
	node.skin = skin
	node.skeleton = NodePath("..")
	var bounds := source.mesh.get_aabb()
	var scale := 2.0 / maxf(bounds.size.length(), 0.001)
	skeleton.scale = Vector3.ONE * scale
	skeleton.position = Vector3(0, 0, -3) - bounds.get_center() * scale
	var material := ShaderMaterial.new()
	material.shader = shader
	for parameter in ["albedo_texture", "mask_texture", "shade_texture"]:
		material.set_shader_parameter(parameter, white)
	material.set_shader_parameter("packet_texture", packet)
	node.material_override = material
	skeleton.add_child(node)

static func add_lights(parent: Node3D) -> void:
	for mode in [OmniLight3D.SHADOW_CUBE, OmniLight3D.SHADOW_DUAL_PARABOLOID]:
		var light := OmniLight3D.new()
		light.omni_shadow_mode = mode
		light.omni_range = 10
		light.position = Vector3(0, 1, -1)
		light.shadow_enabled = true
		parent.add_child(light)
	var area := AreaLight3D.new()
	area.area_range = 10
	area.shadow_enabled = true
	parent.add_child(area)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	parent.add_child(sun)
	var spot := SpotLight3D.new()
	spot.shadow_enabled = true
	parent.add_child(spot)

static func prepare(scene: Node3D, source: Viewport) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(64, 64)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	preload("res://scene_view.gd").configure_rendering(viewport, source)
	viewport.positional_shadow_atlas_size = 512
	viewport.positional_shadow_atlas_16_bits = source.positional_shadow_atlas_16_bits
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	scene.add_child(viewport)
	var root := Node3D.new()
	viewport.add_child(root)
	var camera := Camera3D.new()
	root.add_child(camera)
	add_lights(root)
	var materials: RefCounted = scene.materials
	var shaders: Array = [materials.COLOR_SHADER, materials.color_two_sided, materials.METADATA_SHADER,
		materials.metadata_two_sided, materials.pbr.SHADER, materials.pbr.two_sided, materials.empty_surface.shader]
	shaders.append_array([materials.TRANSPARENT_DEPTH_SHADER, materials.depth_two_sided])
	shaders.append_array(materials.transparent_shaders.values())
	shaders.append(materials.object_appearance.template.shader)
	var white := texture(Color.WHITE)
	var packet := texture(Color(0.5, 0.5, 3000, 1))
	var formats: Dictionary = {}
	for template in scene.templates.values():
		for instance in template.find_children("mesh_*", "MeshInstance3D", true, false):
			if not instance.mesh is ArrayMesh or instance.mesh.get_surface_count() == 0: continue
			var format: int = instance.mesh.surface_get_format(0)
			if formats.has(format) or instance.skin == null: continue
			formats[format] = true
			for shader in shaders: add_mesh(root, instance, shader, white, packet)
	var effects := WorldEffects.new()
	root.add_child(effects)
	var points := PackedFloat32Array()
	for point in [Vector3(-1, 1, -2), Vector3(1, 1, -2), Vector3(-1, -1, -2), Vector3(1, -1, -2)]:
		points.append_array([point.x, point.y, point.z, 0, 0.5, 0.5, 1, 1, 1, 2, 0, 0])
	points.resize(WorldEffects.DATA_WIDTH * 4)
	for identity in [""] + materials.effect_materials.definitions.keys():
		var pair: Array[ShaderMaterial] = materials.effect_materials.pair(identity, WorldEffects.SHADER, WorldEffects.DEPTH_SHADER)
		var batch := effects.create_batch(16, white, white, pair)
		batch.data.update(Image.create_from_data(WorldEffects.DATA_WIDTH, 1, false, Image.FORMAT_RGBAF, points.to_byte_array()))
		for material in [batch.material, batch.depth]:
			material.set_shader_parameter("quad_count", 1)
	for _frame in 4: await RenderingServer.frame_post_draw
	viewport.free()
