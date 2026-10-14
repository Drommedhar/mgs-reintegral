@tool
extends RefCounted

var root := ""
var files: Dictionary = {}
var error := ""
var dependency_check_only := false
var aliases: Dictionary = {}
const ResourceText = preload("res://addons/mgs_editor/resource_text.gd")
const Provenance = preload("res://addons/mgs_editor/export_provenance.gd")
const Gltf = preload("res://addons/mgs_editor/export_gltf.gd")
const SourceCode = preload("res://addons/mgs_editor/source_code.gd")
const ModResources = preload("res://mod_resources.gd")
var catalog_paths: Array = Provenance.CATALOGS
var provenance := Provenance.new()
const MANIFEST_RESOURCES = {
	"replacements":["path"], "stages":["scene"], "materials":["albedo", "normal", "orm", "emission"],
	"effects":["material", "depth_shader"], "appearances":["material"], "postprocess":["effect"], "ui":["scene"], "resources":["path"]}

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
	error = provenance.inspect(files[path], path)
	if not error.is_empty(): return
	var extension := path.get_extension().to_lower()
	if extension in ["tscn", "tres", "gd", "gdshader", "gdshaderinc"]:
		collect_text(path, FileAccess.get_file_as_string(path))
	elif extension in ["res", "scn"]:
		if not dependency_check_only: aliases[path] = converted_path(path)
		for dependency in ResourceLoader.get_dependencies(path):
			var reference: String = dependency.get_slice("::", 2) if "::" in dependency else dependency
			collect(reference if reference.is_absolute_path() else path.get_base_dir().path_join(reference))
		if not error.is_empty(): return
		if dependency_check_only: return
		var reader := ResourceText.new()
		var text := reader.read(path, provenance)
		if not reader.error.is_empty():
			error = reader.error
			return
		collect_text(path, text)
	elif extension in ["gltf", "glb"]:
		var model := Gltf.new()
		model.inspect(files[path], path, provenance)
		if not model.error.is_empty(): error = model.error + ": " + path
		else:
			for dependency in model.dependencies: collect(dependency)
	elif extension == "gdextension":
		collect_extension(path)

func converted_path(path: String) -> String:
	var extension := ResourceText.extension_for(path)
	var candidate := path.get_basename() + "." + extension
	var suffix := 0
	while FileAccess.file_exists(candidate) or candidate in aliases.values():
		suffix += 1
		candidate = "%s.%d.%s" % [path, suffix, extension]
	return candidate

func collect_text(path: String, content: String) -> void:
	if path.get_extension() == "gd":
		var runtime_load := RegEx.new()
		runtime_load.compile(r"""\bload\s*\(\s*["']""")
		var code := SourceCode.mask(content, "gd")
		for match in runtime_load.search_all(content):
			if code[match.get_start()] == " ": continue
			error = "Export cannot relocate script load() paths; use preload() or register Assets > Mod resources and call resolve_mod_resource(): " + path
			return
	if path.get_extension().to_lower() in ["tscn", "tres", "scn", "res"]:
		if "metadata/mgs_edit_error" in content:
			error = "Fix the model edit error shown in the scene before exporting: " + path
			return
		for marker in ["metadata/mgs_asset_id", "metadata/mgs_editor_preview", "metadata/mgs_retail_derived", ".generated/", ".local/godot-content"]:
			if marker in content:
				error = "Export refuses original geometry or a local preview: " + path
				return
		content = relocate_shader_code(path, content)
	content = relocate_references(path, content)
	if not dependency_check_only and error.is_empty() and path.get_extension().to_lower() in ["tres", "tscn"] and 'type="Image"' in content:
		var resource := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		if resource == null: error = "Cannot inspect embedded images: " + path
		else: error = provenance.images.inspect_resource(resource, path)
	var uid := RegEx.new()
	uid.compile(' uid="uid://[^"]+"')
	files[path] = uid.sub(content, "", true).to_utf8_buffer()

func relocate_shader_code(path: String, content: String) -> String:
	var code := RegEx.new()
	code.compile('(?m)^code = "((?:[^"\\\\]|\\\\.)*)"')
	var matches := code.search_all(content)
	matches.reverse()
	for match in matches:
		var source := match.get_string(1).c_unescape()
		var relocated := relocate_references(path, source, "shader").c_escape()
		content = content.left(match.get_start(1)) + relocated + content.substr(match.get_end(1))
	return content

func relocate_references(path: String, content: String, language: String = "") -> String:
	if language.is_empty():
		var extension: String = str(aliases.get(path, path)).get_extension().to_lower()
		language = "gd" if extension == "gd" else ("shader" if extension in ["gdshader", "gdshaderinc"] else "resource")
	var code := SourceCode.mask(content, language)
	var references := RegEx.new()
	references.compile(r"""(?:\[ext_resource[^\n]*path=|\bpreload\s*\(\s*|#include\s+|\bextends\s+)(["'])([^"'\n]+)\1""")
	var matches := references.search_all(content)
	matches.reverse()
	for match in matches:
		if code[match.get_start()] == " ": continue
		var reference := match.get_string(2)
		var dependency := reference if reference.is_absolute_path() else path.get_base_dir().path_join(reference)
		collect(dependency)
		dependency = ProjectSettings.globalize_path(dependency).simplify_path()
		var relative := relative_path(path.get_base_dir(), aliases.get(dependency, dependency))
		content = content.left(match.get_start(2)) + relative + content.substr(match.get_end(2))
	return content

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

func prepare(manifest_path: String) -> String:
	root = ProjectSettings.globalize_path(manifest_path.get_base_dir()).simplify_path()
	files.clear()
	aliases.clear()
	error = ""
	if not FileAccess.file_exists(manifest_path): return "Save the workspace before exporting: " + manifest_path
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not manifest is Dictionary or manifest.get("schema") != 1: return "Invalid mod manifest"
	if not manifest.get("id") is String or str(manifest.id).strip_edges().is_empty(): return "Mod manifest requires an ID"
	error = ModResources.validate(root, manifest.get("resources", {}))
	if not error.is_empty(): return error
	error = provenance.load_catalogs(catalog_paths)
	if not error.is_empty(): return error
	for section in MANIFEST_RESOURCES:
		var entries = manifest.get(section, {})
		if not entries is Dictionary: return "Mod %s must be an object" % section
		for entry in entries.values():
			if not entry is Dictionary: return "Invalid mod entry in " + section
			for field in MANIFEST_RESOURCES[section]:
				if section == "materials" and not entry.has(field): continue
				if not entry.get(field) is String: return "%s requires a %s path" % [section, field]
				var path: String = root.path_join(entry[field]).simplify_path()
				collect(path)
				entry[field] = str(aliases.get(path, path)).trim_prefix(root + "/")
	if not manifest.get("extensions", []) is Array: return "Mod extensions must be an array"
	for entry in manifest.get("extensions", []):
		if not entry is Dictionary or not entry.get("path") is String: return "Extension requires a path"
		collect(root.path_join(entry.path))
	if not error.is_empty(): return error
	var packaged := {}
	for path in files: packaged[aliases.get(path, path)] = files[path]
	files = packaged
	files[root.path_join("mod.json")] = (JSON.stringify(manifest, "\t") + "\n").to_utf8_buffer()
	return error

func export_mod(manifest_path: String, destination: String, overwrite: bool = false) -> String:
	destination = ProjectSettings.globalize_path(destination).simplify_path()
	if destination.get_extension().to_lower() != "zip": return "Mod archives must use the .zip extension"
	if FileAccess.file_exists(destination) and not overwrite: return "Export destination already exists"
	var prepared := prepare(manifest_path)
	if not prepared.is_empty(): return prepared
	if files.has(destination): return "Export cannot overwrite a mod dependency: " + destination
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
