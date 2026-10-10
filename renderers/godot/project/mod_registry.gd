@tool
extends RefCounted

var replacements: Dictionary = {}
var stages: Dictionary = {}
var loaded: Array[String] = []

static func asset_path(root: String, relative: String) -> String:
	if relative.is_empty() or relative.is_absolute_path():
		return ""
	var resolved := root.path_join(relative).simplify_path()
	return resolved if resolved.begins_with(root.simplify_path().trim_suffix("/") + "/") else ""

func configure(catalog: Dictionary, paths: Array) -> String:
	var manifests: Array[Dictionary] = []
	var ids: Dictionary = {}
	for path in paths:
		if not path is String:
			return "Mod manifest paths must be strings"
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary or parsed.get("schema") != 1:
			return "Invalid mod manifest: " + path
		if not parsed.get("id") is String or parsed.id.is_empty() or ids.has(parsed.id):
			return "Mod IDs must be nonempty and unique: " + path
		if not parsed.get("priority", 0) is float and not parsed.get("priority", 0) is int:
			return "Mod priority must be numeric: " + path
		if not parsed.get("replacements", {}) is Dictionary or not parsed.get("stages", {}) is Dictionary:
			return "Mod replacements/stages must be objects: " + path
		ids[parsed.id] = true
		parsed["root"] = str(path).get_base_dir()
		manifests.append(parsed)
	manifests.sort_custom(func(a, b):
		if a.get("priority", 0) == b.get("priority", 0): return a.id < b.id
		return a.get("priority", 0) < b.get("priority", 0))
	for manifest in manifests:
		var error := register_manifest(catalog, manifest)
		if not error.is_empty():
			return "%s: %s" % [manifest.id, error]
		loaded.append(manifest.id)
	return ""

func register_manifest(catalog: Dictionary, manifest: Dictionary) -> String:
	for identity in manifest.get("replacements", {}):
		var entry = manifest.replacements[identity]
		if not catalog.has(identity) or not entry is Dictionary or not entry.get("path") is String:
			return "Unknown asset or invalid replacement: " + str(identity)
		var path := asset_path(manifest.root, entry.path)
		if path.is_empty() or not FileAccess.file_exists(path):
			return "Missing replacement or path outside mod folder: " + entry.path
		var extension := path.get_extension().to_lower()
		if catalog[identity].kind == "model" and extension not in ["gltf", "glb", "tscn"]:
			return "Model replacement requires glTF, GLB or TSCN"
		if catalog[identity].kind == "texture" and extension not in ["png", "webp"]:
			return "Texture replacement requires PNG or WebP"
		if entry.get("lighting", "unlit") not in ["unlit", "lit"]:
			return "Replacement lighting must be unlit or lit"
		replacements[identity] = {"path": path, "lighting": entry.get("lighting", "unlit"), "mod": manifest.id}
	for stage in manifest.get("stages", {}):
		var entry = manifest.stages[stage]
		if stage not in ["s00a", "s01a", "d00a", "d01a"] or not entry is Dictionary or not entry.get("scene") is String:
			return "Invalid prototype stage override: " + str(stage)
		var path := asset_path(manifest.root, entry.scene)
		if path.is_empty() or path.get_extension() != "tscn" or not FileAccess.file_exists(path):
			return "Stage override requires an existing TSCN inside the mod folder"
		if not entry.get("original_lighting", true) is bool:
			return "original_lighting must be boolean"
		stages[stage] = {"path": path, "original_lighting": entry.get("original_lighting", true), "mod": manifest.id}
	return ""
