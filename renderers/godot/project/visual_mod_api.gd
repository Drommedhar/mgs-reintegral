extends Node3D

signal stage_changed(stage: String)
signal snapshot_updated
signal native_context_updated
signal native_actors_updated
signal camera_update_requested

var scene: Node3D
var extensions: Array[Node] = []
var last_stage := ""
var native_context: Dictionary = {}
var native_actors: Node3D
var actor_bindings: Array[Node] = []
var presentation_cameras := preload("res://presentation_cameras.gd").new()
var settings: Node
var save_actions: Node
var title_actions: Node
var options_actions: Node

var codec_actions: Node
var inventory_actions: Node
const ModelEdits = preload("res://model_edits.gd")
var view_ranges: Dictionary = {}

func set_view_distance(owner_node: Node, distance: float) -> String:
	if scene == null or not is_instance_valid(owner_node): return "View distance requires an active scene and owner"
	if not is_finite(distance) or distance < 0 or distance > 10000: return "View distance must be 0–10000 metres"
	if distance == 0: view_ranges.erase(owner_node)
	else: view_ranges[owner_node] = distance
	var far := 250.0
	for owner_key in view_ranges.keys():
		if not is_instance_valid(owner_key): view_ranges.erase(owner_key)
		else: far = maxf(far, view_ranges[owner_key])
	scene.camera.far = far
	scene.metadata_camera.far = far
	return ""

func owns_underwater_view() -> bool:
	if scene == null: return false
	for region in get_tree().get_nodes_in_group("mgs_water_regions"):
		if region.owns_underwater_view(scene.camera.global_position):
			return true
	return false

func has_actor_binding(instance: int) -> bool:
	return actor_bindings.any(func(binding): return binding.bound_instance == instance)

func update_actor_visuals(entry: Dictionary, instance: int, poses: Array[Transform3D]) -> String:
	var applied: Dictionary = entry.get("actor_edit_bindings", {})
	for binding in actor_bindings:
		if binding.bound_instance != instance: continue
		if binding.has_method("apply_part_poses"): binding.apply_part_poses(poses)
		var edits: Dictionary = binding.get_meta("mgs_part_edits", {})
		if edits.is_empty() or applied.has(binding.get_instance_id()): continue
		var error := ModelEdits.apply(entry.node, edits)
		if not error.is_empty(): return error
		applied[binding.get_instance_id()] = true
		entry.actor_edit_bindings = applied
		entry.material_stages.clear()
		for index in entry.meshes.size():
			if entry.metadata_meshes.is_empty(): break
			entry.metadata_meshes[index].mesh = entry.meshes[index].mesh
			entry.metadata_meshes[index].transform = entry.meshes[index].transform
	return ""

func get_inventory_actions() -> Node:
	return inventory_actions

func get_codec_actions() -> Node:
	return codec_actions

func get_title_actions() -> Node:
	return title_actions

func get_options_actions() -> Node:
	return options_actions

func get_settings_provider() -> Node:
	return settings

func resolve_mod_resource(requester: Object, key: String) -> Dictionary:
	if scene == null: return {"status":"unavailable", "message":"No mod resource registry is connected"}
	return scene.mods.resources.resolve(requester, key)

func get_save_actions() -> Node:
	return save_actions

func register_thermal_source(mesh: MeshInstance3D, heat: float = 1.0) -> String:
	if scene == null: return "Thermal source registration requires an active scene"
	return scene.thermal_sources.register(mesh, heat)

func unregister_thermal_source(mesh: MeshInstance3D) -> void:
	if scene != null: scene.thermal_sources.unregister(mesh)

func register_presentation_camera(camera: Camera3D, scope: String = "gameplay", clip: String = "") -> String:
	var error: String = presentation_cameras.register(camera, scope, clip)
	if error.is_empty() and scope == "clip":
		error = validate_presentation_clip(clip)
		if not error.is_empty():
			presentation_cameras.unregister(camera)
			return presentation_cameras.reject(camera, error)
	return error

func validate_presentation_clip(clip: String) -> String:
	var error: String = presentation_cameras.validate_clip(clip)
	if not error.is_empty() or scene == null: return error
	var disc := clip.get_slice("/", 2).trim_prefix("disc").to_int()
	if not scene.content.for_disc(disc).get("cinematics", {}).has(clip):
		return "Presentation camera clip is not prepared: " + clip
	return ""

func unregister_presentation_camera(camera: Camera3D) -> void:
	presentation_cameras.unregister(camera)

func request_camera_cut(camera: Camera3D) -> void:
	presentation_cameras.request_cut(camera)

func set_presentation_camera_error(owner_node: Node, message: String) -> void:
	if not is_instance_valid(owner_node): return
	if message.is_empty(): presentation_cameras.registration_errors.erase(owner_node.get_instance_id())
	else: presentation_cameras.reject(owner_node, "%s: %s" % [owner_node.get_path(), message])

func _ready() -> void:
	add_to_group("mgs_visual_api_v1")

func register_actor_binding(binding: Node) -> void:
	if binding not in actor_bindings: actor_bindings.append(binding)

func unregister_actor_binding(binding: Node) -> void:
	actor_bindings.erase(binding)

func apply_actor_removals(entry: Dictionary, instance: int) -> void:
	for binding in actor_bindings:
		if binding.bound_instance != instance: continue
		if binding.hide_original_object:
			entry.node.hide()
			return
		for index in entry.meshes.size():
			var part := str(entry.meshes[index].name).trim_prefix("mesh_").to_int()
			if part in binding.hide_original_parts:
				entry.meshes[index].hide()
				if not entry.metadata_meshes.is_empty(): entry.metadata_meshes[index].hide()

func get_native_actors() -> Array[Dictionary]:
	return native_actors.snapshot() if native_actors != null else []

func resolve_native_actor(target: Dictionary) -> Dictionary:
	if native_actors == null:
		return {"status": "unavailable", "message": "No native actor provider is connected"}
	return native_actors.resolve_declaration(target)

func get_native_context() -> Dictionary:
	return native_context.duplicate(true)

func publish_native_context(context: Dictionary) -> void:
	native_context = context.duplicate(true)
	if native_actors != null: native_actors.set_epoch(context.epoch)
	native_context_updated.emit()

func get_api_version() -> int:
	return 1

func get_stage() -> String:
	return scene.scene_stage

func get_camera() -> Camera3D:
	return scene.camera

func get_instances() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in scene.instances:
		var instance: Dictionary = scene.instances[id]
		result.append({"id": id, "asset": instance.asset, "node": instance.node,
			"thermal": instance.get("thermal", false),
			"appearance": instance.get("appearance", {"kind": 0}).duplicate(true)})
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
		extension.set_meta("mgs_mod_package", definition.mod)
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
	view_ranges.clear()
	presentation_cameras.cameras.clear()
	presentation_cameras.registration_errors.clear()
	actor_bindings.clear()
	for index in range(extensions.size() - 1, -1, -1):
		var extension := extensions[index]
		extension.call("mgs_mod_shutdown")
		extension.free()
	extensions.clear()
	native_context.clear()
	native_actors = null
	scene = null
