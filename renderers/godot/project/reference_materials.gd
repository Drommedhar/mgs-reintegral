extends RefCounted

const COLOR_SHADER = preload("res://reference.gdshader")
const METADATA_SHADER = preload("res://reference_metadata.gdshader")
const METADATA_LAYER = 1 << 19
var color_two_sided := Shader.new()
var metadata_two_sided := Shader.new()
var textures: Dictionary = {}
var masks: Dictionary = {}
var empty_mask: ImageTexture
var catalog: Dictionary
var mods: RefCounted
var asset_root: String

func initialize(assets: Dictionary, registry: RefCounted, root: String) -> void:
	catalog = assets
	mods = registry
	asset_root = root
	color_two_sided.code = COLOR_SHADER.code.replace("unshaded, fog_disabled", "unshaded, fog_disabled, cull_disabled")
	metadata_two_sided.code = METADATA_SHADER.code.replace("unshaded, fog_disabled", "unshaded, fog_disabled, cull_disabled")
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.BLACK)
	empty_mask = ImageTexture.create_from_image(image)

func texture_identity(legacy_id: String, scene_stage: String, definition_stage: String) -> String:
	for stage in [scene_stage, definition_stage, "init"]:
		var identity := "mgs/integral-j/disc1/stage/%s/%s.p" % [stage, legacy_id]
		if catalog.has(identity): return identity
	return ""

func texture_for(identity: String, mask: bool) -> Texture2D:
	if mask and mods.replacements.has(identity): return empty_mask
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
	if mods.replacements.has(entry.asset): return
	for mesh in entry.meshes:
		var copy := MeshInstance3D.new()
		copy.name = "metadata_" + str(mesh.name)
		copy.mesh = mesh.mesh
		copy.skin = mesh.skin
		copy.skeleton = mesh.skeleton
		copy.transform = mesh.transform
		copy.layers = METADATA_LAYER
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	if metadata:
		material.set_shader_parameter("mask_texture", texture_for(identity, true))
		material.set_shader_parameter("quantize_color", quantize and not mods.replacements.has(identity))
	return material

func apply(entry: Dictionary, stage: String) -> void:
	var replaced: bool = mods.replacements.has(entry.asset)
	var original_lighting: bool = not mods.stages.has(stage) or mods.stages[stage].original_lighting
	for index in entry.meshes.size():
		var mesh: MeshInstance3D = entry.meshes[index]
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if original == null: continue
			if replaced:
				var material := original.duplicate() as StandardMaterial3D
				material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL if mods.replacements[entry.asset].lighting == "lit" else BaseMaterial3D.SHADING_MODE_UNSHADED
				mesh.set_surface_override_material(surface, material)
				continue
			var identity := texture_identity(original.resource_name.get_slice("_", 0), stage, str(entry.asset).get_slice("/", 4))
			if identity.is_empty():
				push_error("Prepared material texture missing: " + original.resource_name)
				continue
			entry.metadata_meshes[index].set_surface_override_material(surface, packet_material(entry, original, identity, true, original_lighting))
			if original_lighting:
				mesh.set_surface_override_material(surface, packet_material(entry, original, identity, false, true))
			else:
				var material := original.duplicate() as StandardMaterial3D
				material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
				material.albedo_texture = texture_for(identity, false)
				material.albedo_color = Color.WHITE
				mesh.set_surface_override_material(surface, material)
