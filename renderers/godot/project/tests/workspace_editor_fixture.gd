@tool
extends Node

const State = preload("res://addons/mgs_editor/workspace_state.gd")
var worker := false
var failures := 0

func _ready() -> void:
	if worker or not Engine.is_editor_hint() or OS.get_environment("MGS_WORKSPACE_EDITOR_TEST") != "1": return
	var runner: Node = get_script().new()
	runner.worker = true
	get_tree().root.add_child(runner)
	runner.run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func settle() -> void:
	for frame in 5: await get_tree().process_frame

func run() -> void:
	await settle()
	var plugin: EditorPlugin
	for candidate in get_tree().root.find_children("*", "EditorPlugin", true, false):
		if candidate.get_script() != null and candidate.get_script().resource_path == "res://addons/mgs_editor/plugin.gd": plugin = candidate
	if plugin == null:
		push_error("Workspace test requires MGS editor plugin")
		get_tree().quit(1)
		return
	var previous: String = plugin.workspace.root
	while plugin.catalog_loading: await get_tree().process_frame
	var identity := "test.editor.workspace.%d" % Time.get_ticks_usec()
	var source := "res://mods/" + identity
	var copy := source + ".copy"
	var destination := ProjectSettings.globalize_path("res://../../../build/godot-sdk-m0/" + identity + ".zip")
	plugin.picker.select(source, false)
	var data: Dictionary = plugin.workspace.manifest()
	data.id = identity
	check(plugin.workspace.save(data), "Cannot initialize isolated workspace")
	plugin.refresh_mod_views(data)
	plugin.stages.search.text = "Loading Dock"
	plugin.stages.populate()
	plugin.create_stage()
	await settle()
	var root := EditorInterface.get_edited_scene_root()
	check(root != null and root.has_node("_MapSession"), "Native map preview did not attach")
	if root == null or not root.has_node("_MapSession"):
		get_tree().quit(1)
		return
	var material := StandardMaterial3D.new()
	var material_path := source.path_join("authored.tres")
	check(ResourceSaver.save(material, material_path) == OK, "Cannot initialize custom material")
	material.take_over_path(material_path)
	var authored := MeshInstance3D.new()
	authored.name = "AuthoredBox"
	authored.mesh = BoxMesh.new()
	authored.material_override = material
	root.add_child(authored)
	authored.owner = root
	EditorInterface.mark_scene_as_unsaved()
	EditorInterface.edit_resource(material)
	await settle()
	material.roughness = 0.23
	EditorInterface.get_inspector().property_edited.emit("roughness")
	check(plugin.workspace_actions.pending_resources.has(material_path), "Inspector edit was not tracked")
	plugin.workspace_actions.version.text = "0.2"
	check(await plugin.workspace_actions.save_workspace(), "Workspace save failed")
	check(EditorInterface.get_unsaved_scenes().find(root.scene_file_path) == -1, "Workspace scene remains unsaved")
	var saved_material := ResourceLoader.load(material_path, "", ResourceLoader.CACHE_MODE_IGNORE) as StandardMaterial3D
	check(is_equal_approx(saved_material.roughness, 0.23), "Inspector resource edit was not saved")
	await plugin.workspace_actions.write_export(destination, true)
	check(FileAccess.file_exists(destination), "First ZIP was not exported")
	var first := FileAccess.get_sha256(destination)
	authored.position = Vector3(2, 3, 4)
	EditorInterface.mark_scene_as_unsaved()
	await plugin.workspace_actions.export_current()
	check(FileAccess.get_sha256(destination) != first, "Repeated Export did not update saved scene")
	check(State.new().read(source).version == "0.2", "Export version was lost")
	await plugin.picker.open_zip(destination)
	await settle()
	check(plugin.workspace.root == source, "Open ZIP did not resume the active workspace")
	plugin.workspace_actions.fork_id.text = identity + ".copy"
	plugin.workspace_actions.fork_name.text = "Independent editor copy"
	await plugin.workspace_actions.fork_workspace()
	await settle()
	check(plugin.workspace.root == copy, "Save As did not select the new workspace")
	check(plugin.workspace.manifest().id == identity + ".copy", "Save As retained source identity")
	check(State.new().read(copy).export_path.is_empty(), "Save As inherited source ZIP destination")
	var copied := EditorInterface.get_edited_scene_root()
	check(copied != null and copied.has_node("AuthoredBox"), "Copied map lost authored object")
	if copied != null and copied.has_node("AuthoredBox"):
		check(copied.get_node("AuthoredBox").position == Vector3(2, 3, 4), "Copy lost latest scene edit")
		check(copied.get_node("AuthoredBox").material_override.resource_path.begins_with(copy + "/"), "Copy still shares source material")
	await plugin.workspace_actions.write_export(destination.trim_suffix(".zip") + ".copy.zip", true)
	var reader := ZIPReader.new()
	check(reader.open(destination) == OK, "Cannot inspect editor ZIP")
	for file in reader.get_files():
		check(not file.begins_with(".editor-"), "Editor history leaked into ZIP")
		if file.ends_with(".tscn"):
			var text := reader.read_file(file).get_string_from_utf8()
			check("metadata/mgs_asset_id" not in text and "metadata/mgs_retail_derived" not in text, "Native map originals leaked into ZIP")
	reader.close()
	plugin.picker.select(previous, false)
	plugin.stages.search.text = ""
	plugin.stages.populate()
	print("MGS_WORKSPACE_EDITOR_TEST source=%s copy=%s zip=%s failures=%d" % [source, copy, destination, failures])
	get_tree().quit(1 if failures else 0)
