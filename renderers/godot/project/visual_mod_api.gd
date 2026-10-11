extends Node3D

signal stage_changed(stage: String)
signal snapshot_updated

var scene: Node3D
var extensions: Array[Node] = []
var last_stage := ""

func get_api_version() -> int:
	return 1

func get_stage() -> String:
	return scene.scene_stage

func get_camera() -> Camera3D:
	return scene.camera

func get_instances() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in scene.instances:
		result.append({"id": id, "asset": scene.instances[id].asset, "node": scene.instances[id].node})
	return result

func start(owner_scene: Node3D, definitions: Array[Dictionary]) -> String:
	scene = owner_scene
	for definition in definitions:
		var path := ProjectSettings.globalize_path(definition.path)
		var status := GDExtensionManager.load_extension(path)
		if status not in [GDExtensionManager.LOAD_STATUS_OK, GDExtensionManager.LOAD_STATUS_ALREADY_LOADED]:
			return "Cannot load GDExtension for %s (status %d): %s" % [definition.mod, status, path]
		if not ClassDB.class_exists(definition.class) or not ClassDB.can_instantiate(definition.class) or not ClassDB.is_parent_class(definition.class, "Node"):
			return "Extension class must be a registered Node: " + definition.class
		var extension := ClassDB.instantiate(definition.class) as Node
		if not extension.has_method("mgs_mod_initialize") or not extension.has_method("mgs_mod_shutdown"):
			extension.free()
			return "Extension requires mgs_mod_initialize and mgs_mod_shutdown: " + definition.class
		extension.name = definition.mod.validate_node_name()
		add_child(extension)
		extensions.append(extension)
		var result = extension.call("mgs_mod_initialize", self)
		if not result is int or result != OK:
			return "Extension initialization failed for %s: %s" % [definition.mod, str(result)]
		print("MGS_EXTENSION %s class=%s api=1" % [definition.mod, definition.class])
	return ""

func publish_snapshot() -> void:
	if scene == null: return
	if last_stage != scene.scene_stage:
		last_stage = scene.scene_stage
		stage_changed.emit(last_stage)
	snapshot_updated.emit()

func stop() -> void:
	for index in range(extensions.size() - 1, -1, -1):
		var extension := extensions[index]
		extension.call("mgs_mod_shutdown")
		extension.free()
	extensions.clear()
	scene = null
