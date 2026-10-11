extends RefCounted

const COLOR_SHADER = preload("res://reference.gdshader")
const METADATA_SHADER = preload("res://reference_metadata.gdshader")
const TRANSPARENT_DEPTH_SHADER = preload("res://reference_transparent_depth.gdshader")
const PbrMaterials = preload("res://pbr_materials.gd")
const ReferenceShader = preload("res://reference_shader.gd")
const METADATA_LAYER = 1 << 19
var color_two_sided := Shader.new()
var metadata_two_sided := Shader.new()
var depth_two_sided := Shader.new()
var pbr := PbrMaterials.new()
var textures: Dictionary = {}
var masks: Dictionary = {}
var empty_mask: ImageTexture
var catalog: Dictionary
var mods: RefCounted
var asset_root: String
var transparent_shaders: Dictionary = {}
var empty_surface := ShaderMaterial.new()

func initialize(assets: Dictionary, registry: RefCounted, root: String) -> String:
	catalog = assets
	mods = registry
	asset_root = root
	color_two_sided = ReferenceShader.two_sided(COLOR_SHADER)
	metadata_two_sided = ReferenceShader.two_sided(METADATA_SHADER)
	depth_two_sided = ReferenceShader.two_sided(TRANSPARENT_DEPTH_SHADER)
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.BLACK)
	empty_mask = ImageTexture.create_from_image(image)
	empty_surface.shader = Shader.new()
	empty_surface.shader.code = "shader_type spatial; void fragment() { discard; }"
	var error := pbr.initialize(mods.materials)
	if not error.is_empty(): return error
	for shader in [COLOR_SHADER, color_two_sided, pbr.SHADER, pbr.two_sided]:
		transparent_shaders[shader] = ReferenceShader.transparent(shader)
	return ""

func prepare_stage(stage: String) -> String:
	for identity in catalog:
		if catalog[identity].kind != "texture" or str(identity).get_slice("/", 4) not in [stage, "init"]:
			continue
		if texture_for(identity, false) == null or texture_for(identity, true) == null:
			return "Cannot load prepared stage texture: " + identity
	return ""

func texture_identity(legacy_id: String, scene_stage: String, definition_stage: String) -> String:
	for stage in [scene_stage, definition_stage, "init"]:
		var identity := "mgs/integral-j/disc1/stage/%s/%s.p" % [stage, legacy_id]
		if catalog.has(identity): return identity
	return ""

func can_prepare_model(template: Node3D, identity: String, stage: String) -> bool:
	if mods.replacements.has(identity): return true
	for mesh in template.find_children("mesh_*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if material == null: continue
			var legacy := material.resource_name.get_slice("_", 0)
			if legacy != "0000" and texture_identity(legacy, stage, identity.get_slice("/", 4)).is_empty():
				return false
	return true

func texture_for(identity: String, mask: bool) -> Texture2D:
	var pbr_albedo: String = mods.materials.get(identity, {}).get("albedo", "")
	if mask and (mods.replacements.has(identity) or not pbr_albedo.is_empty()): return empty_mask
	if not mask and not pbr_albedo.is_empty(): return pbr.textures[pbr_albedo]
	var cache := masks if mask else textures
	if cache.has(identity): return cache[identity]
	var path: String = mods.replacements[identity].path if mods.replacements.has(identity) else asset_root.path_join(catalog[identity].path)
	if mask: path = path.get_basename() + ".stp.png"
	var image := Image.load_from_file(path)
	if image == null:
		push_error("Cannot read prepared texture " + path)
		return null
	var texture := ImageTexture.create_from_image(image)
	cache[identity] = texture
	return texture

func add_metadata_meshes(entry: Dictionary) -> void:
	entry.metadata_meshes = []
	if mods.replacements.has(entry.asset) and not entry.node.get_meta("mgs_reference_model", false): return
	for mesh in entry.meshes:
		var copy := MeshInstance3D.new()
		copy.name = "metadata_" + str(mesh.name)
		copy.mesh = mesh.mesh
		copy.skin = mesh.skin
		copy.skeleton = mesh.skeleton
		copy.transform = mesh.transform
		copy.layers = METADATA_LAYER
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		copy.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		copy.set_meta("mgs_runtime_metadata", true)
		mesh.get_parent().add_child(copy)
		entry.metadata_meshes.append(copy)

func packet_material(entry: Dictionary, original: StandardMaterial3D, identity: String, metadata: bool, quantize: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	var two_sided := original.cull_mode == BaseMaterial3D.CULL_DISABLED
	material.shader = (metadata_two_sided if two_sided else METADATA_SHADER) if metadata else (color_two_sided if two_sided else COLOR_SHADER)
	material.set_shader_parameter("albedo_texture", texture_for(identity, false))
	material.set_shader_parameter("shade_texture", entry.shade)
	material.set_shader_parameter("packet_texture", entry.packets)
	material.set_shader_parameter("quantize_color", quantize and not mods.replacements.has(identity))
	if metadata:
		material.set_shader_parameter("mask_texture", texture_for(identity, true))
	return material

func replacement_material(source: Material, lighting: String) -> Material:
	if not source is BaseMaterial3D: return source
	var material := source.duplicate() as BaseMaterial3D
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL if lighting == "lit" else BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func apply_replacement(mesh: MeshInstance3D, lighting: String) -> void:
	if mesh.material_override != null:
		mesh.material_override = replacement_material(mesh.material_override, lighting)
	for surface in mesh.mesh.get_surface_count():
		mesh.set_surface_override_material(surface, replacement_material(mesh.get_active_material(surface), lighting))

func surface_materials(entry: Dictionary, original: StandardMaterial3D, identity: String, use_original: bool, transparent: bool = false) -> Array:
	var key := "%s:%d:%d:%d" % [identity, original.cull_mode, int(use_original), int(transparent)]
	if entry.surface_materials.has(key): return entry.surface_materials[key]
	var metadata := packet_material(entry, original, identity, true, use_original)
	var color := packet_material(entry, original, identity, false, use_original)
	if not use_original:
		pbr.apply(color, identity, original.cull_mode == BaseMaterial3D.CULL_DISABLED)
	if transparent:
		if not transparent_shaders.has(color.shader): transparent_shaders[color.shader] = ReferenceShader.transparent(color.shader)
		color.shader = transparent_shaders[color.shader]
		color.set_shader_parameter("mask_texture", texture_for(identity, true))
		color.next_pass = transparent_depth(entry, original, identity, use_original)
	entry.surface_materials[key] = [color, metadata]
	return entry.surface_materials[key]

func transparent_depth(entry: Dictionary, original: StandardMaterial3D, identity: String, use_original: bool) -> ShaderMaterial:
	var depth := packet_material(entry, original, identity, false, false)
	depth.shader = depth_two_sided if original.cull_mode == BaseMaterial3D.CULL_DISABLED else TRANSPARENT_DEPTH_SHADER
	depth.set_shader_parameter("original_lighting", use_original)
	depth.render_priority = 126
	return depth

func apply(entry: Dictionary, stage: String) -> String:
	if not entry.node.visible: return ""
	var replaced: bool = mods.replacements.has(entry.asset) and not entry.node.get_meta("mgs_reference_model", false)
	var original_lighting: bool = mods.stage_definition(stage).get("original_lighting", true)
	for index in entry.meshes.size():
		var mesh: MeshInstance3D = entry.meshes[index]
		if not mesh.visible: continue
		var transparent: bool = entry.transparent_parts.get(index, false)
		var alarm_glass: bool = entry.get("alarm_glass", false) and transparent
		var alarm_active: bool = alarm_glass and entry.get("alarm_active", false)
		var material_stage := "%s:%d:%d" % [stage, int(transparent), int(alarm_active)]
		if entry.material_stages.get(index) == material_stage: continue
		if replaced or mesh.get_meta("mgs_custom_geometry", false):
			if not entry.material_stages.has(index): apply_replacement(mesh, mods.replacements[entry.asset].lighting)
			if not entry.metadata_meshes.is_empty(): entry.metadata_meshes[index].material_override = empty_surface
			entry.material_stages[index] = material_stage
			continue
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if original == null: continue
			var legacy_id := original.resource_name.get_slice("_", 0)
			if legacy_id == "0000":
				mesh.set_surface_override_material(surface, empty_surface)
				entry.metadata_meshes[index].set_surface_override_material(surface, empty_surface)
				continue
			var identity := texture_identity(legacy_id, stage, str(entry.asset).get_slice("/", 4))
			if identity.is_empty():
				return "Prepared material texture missing: " + original.resource_name
			if texture_for(identity, false) == null or texture_for(identity, true) == null:
				return "Cannot load prepared material texture: " + identity
			var use_original: bool = original_lighting and not mods.materials.has(identity)
			var pair := surface_materials(entry, original, identity, use_original, transparent)
			if alarm_glass and not use_original:
				pair[0].set_shader_parameter("alarm_emission", 2.0 if alarm_active else 0.0)
				if not mods.materials.has(identity): pair[0].set_shader_parameter("pbr_roughness", 0.2)
			var edited: Material = mesh.get_meta("mgs_material_edits", {}).get(surface)
			if edited != null:
				edited = replacement_material(edited, "lit")
				if edited is BaseMaterial3D and surface in mesh.get_meta("mgs_inherit_albedo", []): edited.albedo_texture = texture_for(identity, false)
			mesh.set_surface_override_material(surface, edited if edited != null else pair[0])
			var metadata: Material = packet_material(entry, original, identity, true, false) if edited != null else pair[1]
			entry.metadata_meshes[index].set_surface_override_material(surface, metadata)
		entry.material_stages[index] = material_stage
	return ""
