@tool
extends EditorPlugin

const ResourcesPanel = preload("res://addons/mgs_editor/mod_resources_editor.gd")
const Workspace = preload("res://addons/mgs_editor/mod_workspace.gd")
var failures := 0
var messages: Array[String] = []
var opened: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	await get_tree().process_frame
	while EditorInterface.get_resource_filesystem().is_scanning(): await get_tree().process_frame
	var workspace := Workspace.new()
	workspace.root = "res://mods/.resources-editor-%d" % Time.get_ticks_usec()
	check(workspace.save(workspace.manifest()), workspace.error)
	var material_path := workspace.root.path_join("paint.tres")
	check(ResourceSaver.save(StandardMaterial3D.new(), material_path) == OK, "Cannot create editor resource")
	var panel := ResourcesPanel.new()
	panel.workspace = workspace
	panel.reported.connect(func(message): messages.append(message))
	panel.open_requested.connect(func(path): opened.append(path))
	add_child(panel)
	panel.open_entry("", "")
	panel.resource_name.text = "paint/alarm"
	panel.picker.file_selected.emit(material_path)
	panel.dialog.confirmed.emit()
	check(workspace.manifest().resources.get("paint/alarm", {}).get("path") == "paint.tres", "File picker did not register a portable path")
	check(panel.list.get_root().get_child_count() == 1, "Registered resource missing from browser")
	panel.list.get_root().get_child(0).select(0)
	panel.list.item_activated.emit()
	check(opened == [material_path], "Open did not target the selected material")
	panel.edit_button.pressed.emit()
	panel.resource_name.text = "paint/ready"
	panel.dialog.confirmed.emit()
	check(not workspace.manifest().resources.has("paint/alarm") and workspace.manifest().resources.has("paint/ready"), "Edit entry did not rename the key")
	panel.search.text = "absent"
	panel.search.text_changed.emit(panel.search.text)
	check(panel.list.get_root().get_child_count() == 0 and panel.remove_button.disabled, "Search left an invisible selection active")
	panel.search.text = "paint"
	panel.search.text_changed.emit(panel.search.text)
	panel.list.get_root().get_child(0).select(0)
	panel.remove_button.pressed.emit()
	check(workspace.manifest().resources.is_empty() and FileAccess.file_exists(material_path), "Remove entry changed the asset file")
	check(messages.is_empty(), "Editor controls reported errors: " + str(messages))
	panel.free()
	print("MGS_MOD_RESOURCES_EDITOR_TEST failures=%d" % failures)
	get_tree().quit(1 if failures else 0)

func _enter_tree() -> void:
	run.call_deferred()
