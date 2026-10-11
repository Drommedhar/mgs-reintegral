extends Node3D

const SHADER = preload("res://world_effect.gdshader")
const DEPTH_SHADER = preload("res://world_effect_depth.gdshader")
const QUAD_BYTES = 196
const DATA_WIDTH = 192
const INITIAL_CAPACITY = 1024
var batches: Dictionary = {}
var quad_count := 0

func create_batch(capacity: int, albedo: Texture2D, mask: Texture2D) -> Dictionary:
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
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("geometry_data", data)
	material.set_shader_parameter("albedo_texture", albedo)
	material.set_shader_parameter("mask_texture", mask)
	node.material_override = material
	var depth := MeshInstance3D.new()
	depth.mesh = mesh
	depth.custom_aabb = node.custom_aabb
	depth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	depth.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var depth_material := ShaderMaterial.new()
	depth_material.shader = DEPTH_SHADER
	depth_material.render_priority = 127
	depth_material.set_shader_parameter("geometry_data", data)
	depth_material.set_shader_parameter("albedo_texture", albedo)
	depth_material.set_shader_parameter("mask_texture", mask)
	depth.material_override = depth_material
	node.add_child(depth)
	add_child(node)
	return {"node": node, "data": data, "material": material, "depth": depth_material, "capacity": capacity, "height": image.get_height()}

func update_effects(payload: PackedByteArray, offset: int, stage: String, materials: RefCounted) -> String:
	if payload.size() - offset < 4: return "Missing world effect count"
	var count := payload.decode_u32(offset)
	offset += 4
	if count > 65536 or payload.size() - offset != count * QUAD_BYTES: return "Invalid world effect payload"
	var groups: Dictionary = {}
	var depths: Dictionary = {}
	for quad in count:
		var start := offset + quad * QUAD_BYTES
		var legacy := "%04x" % payload.decode_u32(start)
		var identity: String = materials.texture_identity(legacy, stage, stage)
		if identity.is_empty(): return "Missing world effect texture " + legacy
		if not groups.has(identity): groups[identity] = PackedByteArray()
		groups[identity].append_array(payload.slice(start + 4, start + QUAD_BYTES))
		depths[identity] = depths.get(identity, 0.0) - payload.decode_float(start + 12)
	for identity in batches: batches[identity].node.hide()
	for identity in groups:
		var bytes: PackedByteArray = groups[identity]
		var quads := bytes.size() / 192
		if not batches.has(identity) or batches[identity].capacity < quads:
			if materials.texture_for(identity, false) == null or materials.texture_for(identity, true) == null:
				return "Cannot load world effect texture " + identity
			if batches.has(identity): batches[identity].node.free()
			batches[identity] = create_batch(maxi(INITIAL_CAPACITY, nearest_po2(quads)), materials.texture_for(identity, false), materials.texture_for(identity, true))
			print("MGS_WORLD_EFFECT texture=%s capacity=%d" % [identity, batches[identity].capacity])
		var batch: Dictionary = batches[identity]
		batch.node.sorting_offset = depths[identity] / quads
		batch.material.render_priority = 1 if bytes.decode_float(12) > 0.0 else 0
		bytes.resize(DATA_WIDTH * batch.height * 16)
		batch.data.update(Image.create_from_data(DATA_WIDTH, batch.height, false, Image.FORMAT_RGBAF, bytes))
		batch.material.set_shader_parameter("quad_count", quads)
		batch.depth.set_shader_parameter("quad_count", quads)
		batch.material.set_shader_parameter("original_lighting", materials.mods.stage_definition(stage).get("original_lighting", true))
		batch.node.show()
	quad_count = count
	return ""
