@tool
extends RefCounted

const Registry = preload("res://mod_registry.gd")
var root := "res://mods/local"
var error := ""

func manifest() -> Dictionary:
	var path := root.path_join("mod.json")
	if not FileAccess.file_exists(path):
		return {"schema": 1, "id": "local.visuals", "priority": 100, "replacements": {}, "stages": {}}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("schema") != 1:
		error = "Invalid mod manifest: " + path
		return {}
	for field in ["replacements", "stages", "materials"]:
		if not data.get(field, {}) is Dictionary:
			error = "Invalid manifest field: " + field
			return {}
		if not data.has(field): data[field] = {}
	return data

func save(data: Dictionary) -> bool:
	if DirAccess.make_dir_recursive_absolute(root) != OK:
		error = "Cannot create mod folder: " + root
		return false
	var file := FileAccess.open(root.path_join("mod.json"), FileAccess.WRITE)
	if file == null:
		error = "Cannot write mod manifest: " + root
		return false
	file.store_string(JSON.stringify(data, "\t") + "\n")
	return true

func replacement_path(identity: String) -> String:
	var data := manifest()
	return Registry.asset_path(root, data.get("replacements", {}).get(identity, {}).get("path", ""))

func register_replacement(identity: String, path: String) -> bool:
	var data := manifest()
	if data.is_empty(): return false
	var absolute := ProjectSettings.globalize_path(path).simplify_path()
	var prefix := ProjectSettings.globalize_path(root).simplify_path().trim_suffix("/") + "/"
	if not absolute.begins_with(prefix):
		error = "Replacement assets must be inside the active mod folder: " + root
		return false
	data.replacements[identity] = {"path": absolute.trim_prefix(prefix), "lighting": "lit"}
	return save(data)

func import_texture(identity: String, source: String) -> String:
	var image := Image.load_from_file(source)
	if image == null:
		error = "Cannot read replacement texture: " + source
		return ""
	var filename := "%s-%s.%s" % [identity.replace("/", "_"), FileAccess.get_sha256(source).left(12), source.get_extension().to_lower()]
	var path := root.path_join("textures").path_join(filename)
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK or DirAccess.copy_absolute(source, path) != OK:
		error = "Cannot copy replacement texture into " + root
		return ""
	return path if register_replacement(identity, path) else ""
