@tool
extends Node

const TextureImports = preload("res://material_texture_import.gd")
var pending := PackedStringArray()
var scheduled := false

func activate(plugin: EditorPlugin) -> void:
	EditorInterface.get_resource_filesystem().resources_reimported.connect(resources_changed)
	plugin.scene_saved.connect(queue_resource)
	plugin.scene_changed.connect(func(scene):
		if scene != null: queue_resource(scene.scene_file_path))

func resources_changed(paths: PackedStringArray) -> void:
	for path in paths: queue_resource(path)

func queue_resource(path: String) -> void:
	if not path.begins_with("res://mods/") or path.get_extension().to_lower() not in ["glb", "gltf", "tscn", "tres"]: return
	if not pending.has(path): pending.append(path)
	if scheduled: return
	scheduled = true
	prepare.call_deferred()

func prepare() -> void:
	var paths := pending.duplicate()
	pending.clear()
	scheduled = false
	var imports := TextureImports.new()
	for path in paths:
		var resource := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if resource == null:
			push_error("Cannot inspect material textures: " + path)
			return
		imports.inspect(resource)
	var changed := imports.configure()
	if not imports.error.is_empty(): push_error(imports.error)
	if not changed.is_empty(): EditorInterface.get_resource_filesystem().reimport_files(changed)
