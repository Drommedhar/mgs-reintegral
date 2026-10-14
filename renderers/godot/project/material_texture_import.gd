@tool
extends RefCounted

var textures := {}
var seen := {}
var error := ""

func inspect(resource: Resource) -> void:
	if resource == null or seen.has(resource.get_instance_id()): return
	seen[resource.get_instance_id()] = true
	if resource is PackedScene:
		var state: SceneState = resource.get_state()
		for node in state.get_node_count():
			inspect(state.get_node_instance(node))
			for property in state.get_node_property_count(node):
				var value = state.get_node_property_value(node, property)
				if value is Resource: inspect(value)
	elif resource is Mesh:
		for surface in resource.get_surface_count(): inspect(resource.surface_get_material(surface))
	elif resource is BaseMaterial3D:
		inspect_material(resource)
		inspect(resource.next_pass)

func texture_path(texture: Texture2D) -> String:
	if texture == null: return ""
	var path := texture.resource_path
	return path if path.begins_with("res://") and FileAccess.file_exists(path + ".import") else ""

func use_texture(texture: Texture2D) -> String:
	var path := texture_path(texture)
	if not path.is_empty() and not textures.has(path): textures[path] = {}
	return path

func inspect_material(material: BaseMaterial3D) -> void:
	if material.texture_filter < BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS: return
	use_texture(material.albedo_texture)
	var normal := use_texture(material.normal_texture) if material.normal_enabled else ""
	if not normal.is_empty(): textures[normal].normal = true
	var roughness := use_texture(material.orm_texture if material is ORMMaterial3D else material.roughness_texture)
	if roughness.is_empty() or normal.is_empty(): return
	var channel: int = BaseMaterial3D.TEXTURE_CHANNEL_GREEN if material is ORMMaterial3D else material.roughness_texture_channel
	var pair := {"source":normal, "channel":channel + 2}
	if textures[roughness].has("pair") and textures[roughness].pair != pair:
		textures[roughness].conflict = true
	else: textures[roughness].pair = pair

func configure() -> PackedStringArray:
	var changed := PackedStringArray()
	for path in textures:
		var config := ConfigFile.new()
		var status := config.load(path + ".import")
		if status != OK:
			error = "Cannot read texture import settings: " + path
			return changed
		var before := config.encode_to_text()
		config.set_value("params", "mipmaps/generate", true)
		var properties: Dictionary = textures[path]
		if properties.get("normal", false) and config.get_value("params", "compress/normal_map", 0) == 0:
			config.set_value("params", "compress/normal_map", 1)
		if properties.has("pair") and not properties.get("conflict", false):
			var mode := int(config.get_value("params", "roughness/mode", 0))
			var normal: String = config.get_value("params", "roughness/src_normal", "")
			if mode == 0 or (mode > 1 and (mode > 6 or not FileAccess.file_exists(normal))):
				config.set_value("params", "roughness/mode", properties.pair.channel)
				config.set_value("params", "roughness/src_normal", properties.pair.source)
		if config.encode_to_text() == before: continue
		if config.save(path + ".import") != OK:
			error = "Cannot save texture import settings: " + path
			return changed
		changed.append(path)
	return changed
