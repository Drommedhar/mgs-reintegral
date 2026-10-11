@tool
extends RefCounted

var root := ""
var files: Dictionary = {}
var error := ""

static func manifest_for_scene(scene_path: String) -> String:
	var directory := scene_path.get_base_dir()
	while directory.begins_with("res://mods/"):
		var manifest := directory.path_join("mod.json")
		if FileAccess.file_exists(manifest): return manifest
		directory = directory.get_base_dir()
	return ""

static func relative_path(directory: String, file: String) -> String:
	var source := directory.split("/")
	var destination := file.split("/")
	var common := 0
	while common < mini(source.size(), destination.size()) and source[common] == destination[common]: common += 1
	return "../".repeat(source.size() - common) + "/".join(destination.slice(common))

func collect(path: String) -> void:
	if not error.is_empty(): return
	path = ProjectSettings.globalize_path(path).simplify_path()
	if not path.begins_with(root + "/"):
		error = "Export dependency is outside the mod folder: " + path
		return
	if files.has(path): return
	if not FileAccess.file_exists(path):
		error = "Export dependency is missing: " + path
		return
	files[path] = FileAccess.get_file_as_bytes(path)
	var extension := path.get_extension().to_lower()
	if extension in ["tscn", "tres", "gd", "gdshader", "gdshaderinc"]:
		collect_text(path)
	elif extension == "gltf":
		var document = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not document is Dictionary:
			error = "Invalid glTF: " + path
			return
		for entry in document.get("buffers", []) + document.get("images", []):
			if entry.has("uri") and not str(entry.uri).begins_with("data:"): collect(path.get_base_dir().path_join(entry.uri))
	elif extension == "gdextension":
		collect_extension(path)

func collect_text(path: String) -> void:
	var content := FileAccess.get_file_as_string(path)
	if path.get_extension() == "gd":
		var runtime_load := RegEx.new()
		runtime_load.compile(r"""\bload\(\s*["']""")
		if runtime_load.search(content) != null:
			error = "Export cannot relocate script load() paths; use preload() for packaged resources: " + path
			return
	if path.get_extension() in ["tscn", "tres"]:
		if "metadata/mgs_edit_error" in content:
			error = "Fix the model edit error shown in the scene before exporting: " + path
			return
		for marker in ["metadata/mgs_asset_id", "metadata/mgs_editor_preview", "metadata/mgs_retail_derived", ".generated/", ".local/godot-content"]:
			if marker in content:
				error = "Export refuses original geometry or a local preview: " + path
				return
	var references := RegEx.new()
	references.compile(r"""(?:\[ext_resource[^\n]*path=|preload\(\s*|#include\s+)(["'])([^"'\n]+)\1""")
	var matches := references.search_all(content)
	matches.reverse()
	for match in matches:
		var reference := match.get_string(2)
		var dependency := reference if reference.is_absolute_path() else path.get_base_dir().path_join(reference)
		collect(dependency)
		var relative := relative_path(path.get_base_dir(), ProjectSettings.globalize_path(dependency).simplify_path())
		content = content.left(match.get_start(2)) + relative + content.substr(match.get_end(2))
	var uid := RegEx.new()
	uid.compile(' uid="uid://[^"]+"')
	files[path] = uid.sub(content, "", true).to_utf8_buffer()

func collect_extension(path: String) -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK or not config.has_section("libraries"):
		error = "Invalid GDExtension descriptor: " + path
		return
	for features in config.get_section_keys("libraries"):
		if not Array(features.split(".")).all(func(feature): return OS.has_feature(feature)): continue
		collect(path.get_base_dir().path_join(config.get_value("libraries", features)))
	if config.has_section("dependencies"):
		for features in config.get_section_keys("dependencies"):
			if not Array(features.split(".")).all(func(feature): return OS.has_feature(feature)): continue
			for dependency in config.get_value("dependencies", features): collect(path.get_base_dir().path_join(dependency))

func export_mod(manifest_path: String, destination: String, overwrite: bool = false) -> String:
	destination = ProjectSettings.globalize_path(destination).simplify_path()
	root = ProjectSettings.globalize_path(manifest_path.get_base_dir()).simplify_path()
	files.clear()
	error = ""
	if FileAccess.file_exists(destination) and not overwrite: return "Export destination already exists"
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not manifest is Dictionary or manifest.get("schema") != 1: return "Invalid mod manifest"
	collect(manifest_path)
	for entry in manifest.get("replacements", {}).values(): collect(root.path_join(entry.path))
	for entry in manifest.get("stages", {}).values(): collect(root.path_join(entry.scene))
	for entry in manifest.get("materials", {}).values():
		for map in ["albedo", "normal", "orm", "emission"]:
			if entry.has(map): collect(root.path_join(entry[map]))
	for entry in manifest.get("extensions", []): collect(root.path_join(entry.path))
	if not error.is_empty(): return error
	var directory_error := DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	if directory_error != OK: return "Cannot create export folder: " + error_string(directory_error)
	var temporary := destination + ".%d.tmp" % Time.get_ticks_usec()
	var write_error := write_archive(temporary)
	if write_error.is_empty():
		var result := DirAccess.rename_absolute(temporary, destination)
		if result != OK: write_error = "Cannot replace mod archive: " + error_string(result)
	if FileAccess.file_exists(temporary): DirAccess.remove_absolute(temporary)
	return write_error

func write_archive(destination: String) -> String:
	var archive := ZIPPacker.new()
	var result := archive.open(destination)
	if result != OK: return "Cannot open mod archive: " + error_string(result)
	for path in files:
		result = archive.start_file(str(path).trim_prefix(root + "/"))
		if result == OK: result = archive.write_file(files[path])
		if result == OK: result = archive.close_file()
		if result != OK: break
	var close_result := archive.close()
	if result != OK or close_result != OK: return "Cannot finish mod archive"
	return ""
