extends Node3D

const SHADER = preload("res://world_effect.gdshader")
const DEPTH_SHADER = preload("res://world_effect_depth.gdshader")
const QUAD_BYTES = 196
const DATA_WIDTH = 192
const INITIAL_CAPACITY = 1024
const SNOW_ID = 0x10000
const SNOW = "mgs/effects/snow"
var batches: Dictionary = {}
var quad_count := 0
var thermal_active := false
var water_ripples := preload("res://water_ripple_router.gd").new()

func _ready() -> void:
	add_to_group("mgs_weather_exclude")

func snow_replaced(position: Vector3, regions: Array[Node]) -> bool:
	var point := to_global(position)
	for region in regions:
		if region.owns_native_snow(point): return true
	return false

func set_thermal_active(active: bool) -> void:
	if thermal_active == active: return
	thermal_active = active
	for batch in batches.values():
		if batch.has("heat_node"): batch.heat_node.visible = active

func prepare_beam_heat(batch: Dictionary) -> String:
	if batch.has("heat_node"): return ""
	var supported := false
	for uniform in batch.depth.shader.get_shader_uniform_list():
		if uniform.name == "thermal_pass" and uniform.type == TYPE_BOOL: supported = true
	if not supported: return "Beam depth shader requires a thermal_pass boolean; update this effect's copied shader"
	var node := MeshInstance3D.new()
	node.mesh = batch.node.mesh
	node.custom_aabb = batch.node.custom_aabb
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	node.layers = preload("res://thermal_sources.gd").LAYER
	node.set_meta("mgs_runtime_metadata", true)
	var material := batch.depth.duplicate() as ShaderMaterial
	material.set_shader_parameter("thermal_pass", true)
	node.material_override = material
	node.visible = thermal_active
	batch.node.add_child(node)
	batch.heat_node = node
	batch.heat = material
	return ""

func effect_textures(identity: String, materials: RefCounted) -> Array:
	if identity != SNOW:
		return [materials.texture_for(identity, false), materials.texture_for(identity, true)]
	var albedo := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	albedo.fill(Color.WHITE)
	var mask := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	mask.fill(Color.BLACK)
	return [ImageTexture.create_from_image(albedo), ImageTexture.create_from_image(mask)]

func create_batch(capacity: int, albedo: Texture2D, mask: Texture2D, overrides: Array[ShaderMaterial] = []) -> Dictionary:
	var vertices := PackedVector3Array()
	vertices.resize(capacity * 4)
	var indices := PackedInt32Array()
	for quad in capacity:
		for corner in [0, 1, 2, 1, 3, 2]: indices.append(quad * 4 + corner)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.custom_aabb = AABB(Vector3.ONE * -250, Vector3.ONE * 500)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var image := Image.create(DATA_WIDTH, ceili(capacity / 16.0), false, Image.FORMAT_RGBAF)
	var data := ImageTexture.create_from_image(image)
	var material := ShaderMaterial.new() if overrides.is_empty() else overrides[0]
	if overrides.is_empty(): material.shader = SHADER
	material.set_shader_parameter("geometry_data", data)
	material.set_shader_parameter("albedo_texture", albedo)
	material.set_shader_parameter("mask_texture", mask)
	node.material_override = material
	var depth := MeshInstance3D.new()
	depth.mesh = mesh
	depth.custom_aabb = node.custom_aabb
	depth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	depth.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var depth_material := ShaderMaterial.new() if overrides.is_empty() else overrides[1]
	if overrides.is_empty(): depth_material.shader = DEPTH_SHADER
	depth_material.render_priority = 127
	depth_material.set_shader_parameter("geometry_data", data)
	depth_material.set_shader_parameter("albedo_texture", albedo)
	depth_material.set_shader_parameter("mask_texture", mask)
	depth.material_override = depth_material
	node.add_child(depth)
	add_child(node)
	return {"node": node, "data": data, "material": material, "depth": depth_material, "capacity": capacity, "height": image.get_height()}

func update_effects(payload: PackedByteArray, offset: int, stage: String, materials: RefCounted, effect_to_view: Transform3D = Transform3D.IDENTITY) -> String:
	if payload.size() - offset < 4: return "Missing world effect count"
	var count := payload.decode_u32(offset)
	offset += 4
	if count > 65536 or payload.size() - offset != count * QUAD_BYTES: return "Invalid world effect payload"
	water_ripples.route(self, payload, offset, count)
	if not water_ripples.error.is_empty(): return water_ripples.error
	var groups: Dictionary = {}
	var depths: Dictionary = {}
	var beams: Dictionary = {}
	var snow_regions: Array[Node] = []
	if is_inside_tree(): snow_regions = get_tree().get_nodes_in_group("mgs_snow_volumes")
	for quad in count:
		if water_ripples.skipped.has(quad): continue
		var start := offset + quad * QUAD_BYTES
		var resource := payload.decode_u32(start)
		var position := Vector3(payload.decode_float(start + 4), payload.decode_float(start + 8), payload.decode_float(start + 12))
		if resource == SNOW_ID and not snow_regions.is_empty() and snow_replaced(position, snow_regions): continue
		var legacy := "%04x" % resource
		var identity: String = SNOW if resource == SNOW_ID else materials.texture_identity(legacy, stage, stage, materials.current_disc)
		if identity.is_empty(): return "Missing world effect texture " + legacy
		if not groups.has(identity): groups[identity] = PackedByteArray()
		groups[identity].append_array(payload.slice(start + 4, start + QUAD_BYTES))
		if int(payload.decode_float(start + 40)) & 32: beams[identity] = true
		depths[identity] = depths.get(identity, 0.0) - (effect_to_view * position).z
	for identity in batches: batches[identity].node.hide()
	for identity in groups:
		var bytes: PackedByteArray = groups[identity]
		var quads := bytes.size() / 192
		if not batches.has(identity) or batches[identity].capacity < quads:
			var textures := effect_textures(identity, materials)
			if textures[0] == null or textures[1] == null:
				return "Cannot load world effect texture " + identity
			if batches.has(identity): batches[identity].node.free()
			var pair: Array[ShaderMaterial] = materials.effect_materials.pair(identity, SHADER, DEPTH_SHADER)
			batches[identity] = create_batch(maxi(INITIAL_CAPACITY, nearest_po2(quads)), textures[0], textures[1], pair)
			batches[identity].material.set_shader_parameter("screen_sized", identity == SNOW)
			batches[identity].depth.set_shader_parameter("screen_sized", identity == SNOW)
			print("MGS_WORLD_EFFECT texture=%s capacity=%d mod=%s" % [identity, batches[identity].capacity, materials.mods.effects.get(identity, {}).get("mod", "original")])
		var batch: Dictionary = batches[identity]
		if beams.has(identity):
			var heat_error := prepare_beam_heat(batch)
			if not heat_error.is_empty(): return heat_error + ": " + identity
		batch.node.sorting_offset = depths[identity] / quads
		batch.material.render_priority = 1 if bytes.decode_float(12) > 0.0 else 0
		bytes.resize(DATA_WIDTH * batch.height * 16)
		batch.data.update(Image.create_from_data(DATA_WIDTH, batch.height, false, Image.FORMAT_RGBAF, bytes))
		batch.material.set_shader_parameter("quad_count", quads)
		batch.depth.set_shader_parameter("quad_count", quads)
		if batch.has("heat"): batch.heat.set_shader_parameter("quad_count", quads)
		batch.material.set_shader_parameter("original_lighting", materials.mods.stage_definition(stage, materials.current_disc).get("original_lighting", false))
		batch.node.show()
	quad_count = count
	return ""
