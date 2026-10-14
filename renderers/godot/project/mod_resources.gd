@tool
extends RefCounted

var packages: Dictionary = {}

static func asset_path(root: String, relative: String) -> String:
	if relative.is_empty() or relative.is_absolute_path(): return ""
	var resolved := root.path_join(relative).simplify_path()
	return resolved if resolved.begins_with(root.simplify_path().trim_suffix("/") + "/") else ""

static func validate(root: String, entries: Variant) -> String:
	if not entries is Dictionary: return "Mod resources must be an object"
	for key in entries:
		if not key is String or key.strip_edges().is_empty(): return "Mod resource names must be nonempty strings"
		var entry = entries[key]
		if not entry is Dictionary or entry.size() != 1 or not entry.get("path") is String:
			return "Mod resource %s requires a path" % key
		var path := asset_path(root, entry.path)
		if path.is_empty(): return "Mod resource %s is outside the mod folder: %s" % [key, entry.path]
		if not FileAccess.file_exists(path): return "Mod resource %s is missing: %s" % [key, entry.path]
	return ""

func register_package(identity: String, root: String, entries: Dictionary) -> String:
	var error := validate(root, entries)
	if not error.is_empty(): return error
	var paths := {}
	for key in entries: paths[key] = asset_path(root, entries[key].path)
	packages[identity] = {"root":ProjectSettings.globalize_path(root).simplify_path().trim_suffix("/"), "paths":paths}
	return ""

func package_for_path(path: String) -> String:
	if path.is_empty(): return ""
	var absolute := ProjectSettings.globalize_path(path).simplify_path()
	var selected := ""
	var length := 0
	for identity in packages:
		var prefix: String = packages[identity].root + "/"
		if absolute.begins_with(prefix) and prefix.length() > length:
			selected = identity
			length = prefix.length()
	return selected

func package_for(requester: Object) -> String:
	if not is_instance_valid(requester): return ""
	if requester is Resource:
		var identity := package_for_path(requester.resource_path)
		if not identity.is_empty(): return identity
	var current := requester
	while current != null:
		var identity: String = str(current.get_meta("mgs_mod_package", ""))
		if not identity.is_empty(): return identity
		var script := current.get_script() as Script
		identity = package_for_path(script.resource_path) if script != null else ""
		if not identity.is_empty(): return identity
		if not current is Node: break
		identity = package_for_path(current.scene_file_path)
		if not identity.is_empty(): return identity
		current = current.get_parent()
	return ""

func resolve(requester: Object, key: String) -> Dictionary:
	var identity := package_for(requester)
	if identity.is_empty() or not packages.has(identity):
		return {"status":"unavailable", "message":"Requester does not belong to an enabled mod"}
	var paths: Dictionary = packages[identity].paths
	if not paths.has(key):
		return {"status":"unavailable", "message":"Mod %s has no declared resource named %s" % [identity, key]}
	if not FileAccess.file_exists(paths[key]):
		return {"status":"unavailable", "message":"Mod %s resource %s is missing: %s" % [identity, key, paths[key]]}
	return {"status":"ready", "mod":identity, "path":paths[key]}
