@tool
extends RefCounted

const FILES = ["world_effect_depth.gdshader", "world_effect_geometry.gdshaderinc", "world_effect_appearance.gdshaderinc"]
var error := ""
var resources := preload("res://effect_materials.gd").new()

func open_material(workspace: RefCounted, identity: String) -> ShaderMaterial:
	var manifest: Dictionary = workspace.manifest()
	if manifest.is_empty():
		error = workspace.error
		return null
	var existing: Dictionary = manifest.get("effects", {}).get(identity, {})
	if not existing.is_empty():
		var path: String = preload("res://mod_registry.gd").asset_path(workspace.root, existing.get("material", ""))
		if not path.is_empty():
			error = resources.prepare_textures(path, {})
			if not error.is_empty(): return null
		var resource := load(path) as ShaderMaterial if not path.is_empty() else null
		if resource == null: error = "Cannot open effect material: " + identity
		return resource
	var relative := "effects/" + identity.replace("/", "_")
	var directory: String = workspace.root.path_join(relative)
	var result := DirAccess.make_dir_recursive_absolute(directory)
	var shader_name := "world_footprint.gdshader" if identity.ends_with("/dc55.p") else "world_effect.gdshader"
	for filename in FILES + [shader_name]:
		if result != OK: break
		var destination := directory.path_join(filename)
		if FileAccess.file_exists(destination):
			error = "Unregistered effect files already exist: " + directory
			return null
		result = DirAccess.copy_absolute("res://" + filename, destination)
	var material := ShaderMaterial.new()
	if result == OK:
		material.shader = load(directory.path_join(shader_name)) as Shader
		result = ResourceSaver.save(material, directory.path_join("material.tres"))
	if result != OK:
		error = "Cannot create effect material: " + error_string(result)
		return null
	manifest.effects[identity] = {"material": relative + "/material.tres", "depth_shader": relative + "/world_effect_depth.gdshader"}
	if not workspace.save(manifest):
		error = workspace.error
		return null
	return load(directory.path_join("material.tres")) as ShaderMaterial
