@tool
extends RefCounted

var entries: Array[Dictionary] = []

func read(path: String) -> String:
	if not FileAccess.file_exists(path): return "Mod profile is missing: " + path
	return configure(JSON.parse_string(FileAccess.get_file_as_string(path)))

func configure(data: Variant) -> String:
	var parsed: Array[Dictionary] = []
	if not data is Dictionary or data.get("schema") != 1 or not data.get("mods") is Array:
		return "Mod profile requires schema 1 and a mods array"
	var seen := {}
	for entry in data.mods:
		if not entry is Dictionary or not entry.get("manifest") is String or entry.manifest.is_empty():
			return "Each profile mod requires a manifest path"
		if not entry.get("enabled", true) is bool: return "Profile enabled must be boolean"
		var priority = entry.get("priority", 0)
		if (not priority is float and not priority is int) or not is_finite(priority):
			return "Profile priority must be a finite number"
		var path := ProjectSettings.localize_path(str(entry.manifest).replace("\\", "/")).simplify_path()
		if seen.has(path): return "Mod profile repeats manifest: " + path
		seen[path] = true
		parsed.append({"manifest":path, "enabled":entry.get("enabled", true), "priority":priority})
	entries = parsed
	return ""

func data(absolute: bool = false) -> Dictionary:
	var mods := entries.duplicate(true)
	if absolute:
		for entry in mods: entry.manifest = ProjectSettings.globalize_path(entry.manifest)
	return {"schema":1, "mods":mods}

func save(path: String, absolute: bool = false) -> String:
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK: return "Cannot create profile folder"
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return "Cannot write mod profile: " + path
	file.store_string(JSON.stringify(data(absolute), "\t") + "\n")
	file.close()
	var result := DirAccess.rename_absolute(path + ".tmp", path)
	return "" if result == OK else "Cannot save mod profile: " + error_string(result)

func add(path: String) -> String:
	path = ProjectSettings.localize_path(path.replace("\\", "/")).simplify_path()
	for entry in entries:
		if entry.manifest == path: return ""
	if not FileAccess.file_exists(path): return "Mod manifest is missing: " + path
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not manifest is Dictionary or manifest.get("schema") != 1 or not manifest.get("id") is String:
		return "Invalid mod manifest: " + path
	var priority = manifest.get("priority", 0)
	if (not priority is float and not priority is int) or not is_finite(priority): return "Invalid manifest priority: " + path
	entries.append({"manifest":path, "enabled":true, "priority":priority})
	return ""

func paths() -> Array:
	return entries.filter(func(entry): return entry.enabled).map(func(entry): return entry.manifest)

func priorities() -> Dictionary:
	var result := {}
	for entry in entries:
		if entry.enabled: result[ProjectSettings.globalize_path(entry.manifest).simplify_path()] = entry.priority
	return result
