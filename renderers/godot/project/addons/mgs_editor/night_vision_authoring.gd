@tool
extends RefCounted

var error := ""

func open_effect(workspace: RefCounted, kind: String = "night_vision") -> CompositorEffect:
	error = ""
	if kind not in ["night_vision", "thermal_vision"]:
		error = "Unknown vision effect: " + kind
		return null
	var manifest: Dictionary = workspace.manifest()
	if manifest.is_empty():
		error = workspace.error
		return null
	var entry: Dictionary = manifest.postprocess.get(kind, {})
	var path: String = preload("res://mod_registry.gd").asset_path(workspace.root, entry.get("effect", ""))
	if entry.is_empty():
		var directory: String = workspace.root.path_join("postprocess/" + kind)
		path = directory.path_join("effect.tres")
		var script_path := directory.path_join(kind + "_effect.gd")
		if FileAccess.file_exists(path) or FileAccess.file_exists(script_path) or FileAccess.file_exists(directory.path_join("night_vision_effect.gd")):
			error = "Unregistered vision resources already exist: " + directory
			return null
		var status := DirAccess.make_dir_recursive_absolute(directory)
		if status == OK: status = DirAccess.copy_absolute("res://" + kind + "_effect.gd", script_path)
		if status == OK and kind == "thermal_vision":
			status = DirAccess.copy_absolute("res://night_vision_effect.gd", directory.path_join("night_vision_effect.gd"))
		if status == OK:
			var script := load(script_path) as Script
			if script == null:
				error = "Cannot load vision effect script: " + script_path
				return null
			status = ResourceSaver.save(script.new(), path)
		if status != OK:
			error = "Cannot create vision effect: " + error_string(status)
			return null
		manifest.postprocess[kind] = {"effect": "postprocess/" + kind + "/effect.tres"}
		if not workspace.save(manifest):
			error = workspace.error
			return null
	if path.is_empty():
		error = "Vision effect must be inside the active mod"
		return null
	var effect := load(path) as CompositorEffect
	if effect == null: error = "Cannot open vision effect: " + path
	return effect
