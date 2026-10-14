@tool
extends RefCounted

var error := ""

static func extension_for(path: String) -> String:
	match ResourceLoader.get_resource_type(path):
		"PackedScene": return "tscn"
		"Shader": return "gdshader"
		"ShaderInclude": return "gdshaderinc"
	return "tres"

func read(path: String, provenance: RefCounted) -> String:
	error = ""
	var resource := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if resource == null:
		error = "Cannot read binary Godot resource: " + path
		return ""
	for marker in ["mgs_asset_id", "mgs_editor_preview", "mgs_retail_derived"]:
		if resource.has_meta(marker):
			error = "Export refuses original geometry or a local preview: " + path
			return ""
	error = provenance.images.inspect_resource(resource, path)
	if not error.is_empty(): return ""
	var extension := extension_for(path)
	var temporary := "user://mod-resource-%d-%d.%s" % [OS.get_process_id(), Time.get_ticks_usec(), extension]
	var result := ResourceSaver.save(resource, temporary)
	var text := ""
	if result != OK: error = "Cannot inspect binary Godot resource: " + path + " (" + error_string(result) + ")"
	else: text = FileAccess.get_file_as_string(temporary)
	if FileAccess.file_exists(temporary): DirAccess.remove_absolute(temporary)
	return canonical_ids(text) if extension in ["tscn", "tres"] else text

static func canonical_ids(text: String) -> String:
	var declarations := RegEx.new()
	declarations.compile('(?m)^\\[(ext_resource|sub_resource) [^\\n]* id="([^"]+)"')
	var ids := {}
	var matches := declarations.search_all(text)
	for index in matches.size():
		var match := matches[index]
		var kind := "ExtResource" if match.get_string(1) == "ext_resource" else "SubResource"
		ids[kind + ":" + match.get_string(2)] = "%s_%d" % [kind, index + 1]
	for index in range(matches.size() - 1, -1, -1):
		var match := matches[index]
		var kind := "ExtResource" if match.get_string(1) == "ext_resource" else "SubResource"
		text = text.left(match.get_start(2)) + ids[kind + ":" + match.get_string(2)] + text.substr(match.get_end(2))
	var references := RegEx.new()
	references.compile('(ExtResource|SubResource)\\("([^"]+)"\\)')
	matches = references.search_all(text)
	for index in range(matches.size() - 1, -1, -1):
		var match := matches[index]
		var key := match.get_string(1) + ":" + match.get_string(2)
		if ids.has(key): text = text.left(match.get_start(2)) + ids[key] + text.substr(match.get_end(2))
	return text
