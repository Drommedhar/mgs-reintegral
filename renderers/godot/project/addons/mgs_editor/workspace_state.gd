@tool
extends RefCounted

const Export = preload("res://addons/mgs_editor/mod_export.gd")
const FILE = ".editor-workspace.json"
var error := ""

static func fingerprint(files: Dictionary) -> String:
	var names := files.keys()
	names.sort()
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	for name in names:
		hash.update((str(name) + "\n").to_utf8_buffer())
		var content := HashingContext.new()
		content.start(HashingContext.HASH_SHA256)
		content.update(files[name])
		hash.update(content.finish())
	return hash.finish().hex_encode()

func read(root: String) -> Dictionary:
	error = ""
	var path := root.path_join(FILE)
	if FileAccess.file_exists(path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not data is Dictionary or data.get("schema") != 1 or not data.get("export_path", "") is String:
			error = "Invalid workspace export history: " + path
			return {}
		return data
	var state := {"schema":1, "export_path":"", "export_sha256":"", "fingerprint":"", "version":""}
	var source_path := root.path_join(".editor-source.json")
	if not FileAccess.file_exists(source_path): return state
	var source = JSON.parse_string(FileAccess.get_file_as_string(source_path))
	if not source is Dictionary or not source.get("zip") is String or not source.get("sha256") is String:
		error = "Invalid imported ZIP provenance: " + source_path
		return {}
	state.export_path = source.zip
	state.export_sha256 = source.sha256
	if not FileAccess.file_exists(source.zip) or FileAccess.get_sha256(source.zip) != source.sha256: return state
	var archive := ZIPReader.new()
	if archive.open(source.zip) != OK: return state
	var files := {}
	for name in archive.get_files():
		if not name.ends_with("/"): files[name] = archive.read_file(name)
	archive.close()
	state.fingerprint = fingerprint(files)
	return state

func snapshot(root: String) -> Dictionary:
	var exporter := Export.new()
	error = exporter.prepare(root.path_join("mod.json"))
	if not error.is_empty(): return {}
	var files := {}
	for path in exporter.files: files[str(path).trim_prefix(exporter.root + "/")] = exporter.files[path]
	var manifest: Dictionary = JSON.parse_string(files["mod.json"].get_string_from_utf8())
	return {"fingerprint":fingerprint(files), "id":manifest.id, "version":str(manifest.get("version", ""))}

func record(root: String, destination: String, current: Dictionary) -> String:
	var data := current.duplicate()
	data.schema = 1
	data.export_path = ProjectSettings.globalize_path(destination).simplify_path()
	data.export_sha256 = FileAccess.get_sha256(data.export_path)
	var path := root.path_join(FILE)
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return "ZIP exported, but cannot save workspace export history: " + path
	file.store_string(JSON.stringify(data, "\t") + "\n")
	file.close()
	var result := DirAccess.rename_absolute(temporary, path)
	if result != OK: return "ZIP exported, but cannot update workspace export history: " + error_string(result)
	return ""

func export_zip(root: String, destination: String, allow_external_change: bool = false) -> String:
	var state := read(root)
	if not error.is_empty(): return error
	destination = ProjectSettings.globalize_path(destination).simplify_path()
	if not allow_external_change and destination == state.get("export_path", "") and FileAccess.file_exists(destination):
		if FileAccess.get_sha256(destination) != state.get("export_sha256", ""):
			return "The ZIP changed outside this workspace. Open it to review the changes, or use Export ZIP As."
	var current := snapshot(root)
	if not error.is_empty(): return error
	var result := Export.new().export_mod(root.path_join("mod.json"), destination, true)
	return record(root, destination, current) if result.is_empty() else result
