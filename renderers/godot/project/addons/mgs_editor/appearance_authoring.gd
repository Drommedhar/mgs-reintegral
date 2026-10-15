@tool
extends RefCounted

var error := ""
var resources := preload("res://effect_materials.gd").new()

func open_material(workspace: RefCounted) -> ShaderMaterial:
	var manifest: Dictionary = workspace.manifest()
	if manifest.is_empty():
		error = workspace.error
		return null
	var entry: Dictionary = manifest.appearances.get("camouflage", {})
	var path: String = preload("res://mod_registry.gd").asset_path(workspace.root, entry.get("material", ""))
	if entry.is_empty():
		var directory: String = workspace.root.path_join("appearances/camouflage")
		path = directory.path_join("material.tres")
		if FileAccess.file_exists(path) or FileAccess.file_exists(directory.path_join("camouflage.gdshader")):
			error = "Unregistered camouflage resources already exist: " + directory
			return null
		var result := DirAccess.make_dir_recursive_absolute(directory)
		if result == OK: result = DirAccess.copy_absolute("res://camouflage.gdshader", directory.path_join("camouflage.gdshader"))
		var material := ShaderMaterial.new()
		if result == OK:
			material.shader = load(directory.path_join("camouflage.gdshader")) as Shader
			result = ResourceSaver.save(material, path)
		if result != OK:
			error = "Cannot create camouflage material: " + error_string(result)
			return null
		manifest.appearances.camouflage = {"material": "appearances/camouflage/material.tres"}
		if not workspace.save(manifest):
			error = workspace.error
			return null
	if path.is_empty():
		error = "Camouflage material must be inside the active mod"
		return null
	error = resources.prepare_textures(path, {})
	if not error.is_empty(): return null
	var restored := load(path) as ShaderMaterial
	if restored == null: error = "Cannot open camouflage material: " + path
	return restored
