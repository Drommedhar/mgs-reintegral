@tool
extends VBoxContainer

signal selected(path: String)
signal reported(message: String)
const State = preload("res://addons/mgs_editor/workspace_state.gd")
var workspace: RefCounted
var version := LineEdit.new()
var summary := Label.new()
var export_dialog := EditorFileDialog.new()
var fork_dialog := ConfirmationDialog.new()
var fork_name := LineEdit.new()
var fork_id := LineEdit.new()
var status_timer := Timer.new()
var snapshot := {}
var history := {}
var history_error := ""
var snapshot_error := ""
var status_check := preload("res://addons/mgs_editor/workspace_status.gd").new()
var dirty := true
var active := ""
var busy := false
var pending_resources := {}
var export_progress := preload("res://addons/mgs_editor/export_progress.gd").new()

func _ready() -> void:
	version.placeholder_text = "Mod version (optional)"
	add_child(version)
	for entries in [[["Save", save_workspace], ["Save As…", choose_fork]],
		[["Export ZIP", export_current], ["Export As…", choose_export]]]:
		var row := HBoxContainer.new()
		add_child(row)
		for entry in entries:
			var button := Button.new()
			button.text = entry[0]
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.pressed.connect(entry[1])
			row.add_child(button)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(summary)
	add_child(export_progress)
	export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_dialog.filters = PackedStringArray(["*.zip ; Mod ZIP"])
	export_dialog.file_selected.connect(func(path): write_export(path, true))
	add_child(export_dialog)
	fork_dialog.title = "Save As new mod"
	fork_dialog.ok_button_text = "Create mod"
	var fields := VBoxContainer.new()
	for entry in [["Mod name", fork_name], ["New mod ID", fork_id]]:
		var label := Label.new()
		label.text = entry[0]
		fields.add_child(label)
		fields.add_child(entry[1])
	fork_dialog.add_child(fields)
	fork_dialog.confirmed.connect(fork_workspace)
	add_child(fork_dialog)
	status_timer.wait_time = 0.75
	status_timer.timeout.connect(refresh)
	add_child(status_timer)
	status_timer.start()
	EditorInterface.get_resource_filesystem().filesystem_changed.connect(invalidate)
	EditorInterface.get_inspector().property_edited.connect(resource_edited)

func resource_edited(_property: StringName) -> void:
	var resource := EditorInterface.get_inspector().get_edited_object() as Resource
	if resource == null or not resource.resource_path.begins_with(workspace.root + "/") or "::" in resource.resource_path: return
	if resource.resource_path.get_extension() not in ResourceSaver.get_recognized_extensions(resource): return
	pending_resources[resource.resource_path] = resource
	invalidate()

func invalidate() -> void:
	dirty = true
	status_check.cancel()

func activate() -> void:
	if active == workspace.root: return
	active = workspace.root
	snapshot.clear()
	snapshot_error = ""
	read_history()
	version.text = str(workspace.manifest().get("version", ""))
	invalidate()
	refresh()

func refresh() -> void:
	if busy or workspace == null: return
	if status_check.worker.is_started() and not status_check.worker.is_alive():
		var result := status_check.finish()
		if not dirty:
			snapshot = result
			history = result.get("history", {})
			history_error = result.get("error", "")
	if dirty and not status_check.worker.is_started():
		var started := status_check.start(workspace.root)
		snapshot_error = "Cannot check workspace status: " + error_string(started) if started != OK else ""
		dirty = false
	var unsaved := Array(EditorInterface.get_unsaved_scenes()).filter(func(path): return path.begins_with(workspace.root + "/"))
	var text := "Saved changes not exported" if snapshot.get("changed", false) else "Workspace matches exported ZIP"
	if not snapshot.get("known", false): text = "Export to check saved changes against the ZIP"
	if history.get("export_path", "").is_empty(): text = "Not exported yet"
	if dirty or status_check.worker.is_started(): text = "Checking saved workspace changes…"
	if not snapshot_error.is_empty(): text = "Export needs attention: " + snapshot_error
	if not history_error.is_empty(): text = history_error
	var resource_changes := pending_resources.keys().any(func(path): return path.begins_with(workspace.root + "/"))
	if not unsaved.is_empty() or resource_changes or version.text != str(workspace.manifest().get("version", "")): text = "Unsaved workspace changes\n" + text
	var destination: String = history.get("export_path", "")
	summary.text = text + ("\nZIP: " + destination if not destination.is_empty() else "")

func save_workspace() -> bool:
	if busy: return false
	busy = true
	var target: String = workspace.root
	var previous := EditorInterface.get_edited_scene_root()
	var previous_path: String = previous.scene_file_path if previous != null else ""
	var error := ""
	for root in EditorInterface.get_open_scene_roots():
		var path: String = root.scene_file_path
		if not path.begins_with(target + "/"): continue
		EditorInterface.open_scene_from_path(path)
		await get_tree().process_frame
		var result := EditorInterface.save_scene()
		if result != OK or path in EditorInterface.get_unsaved_scenes():
			error = "Cannot save workspace scene: " + path + " (" + error_string(result) + ")"
			break
	if not previous_path.is_empty(): EditorInterface.open_scene_from_path(previous_path)
	if workspace.root != target: error = "Active workspace changed while saving. Select the intended mod and retry."
	if error.is_empty():
		for path in pending_resources.keys():
			if not path.begins_with(target + "/"): continue
			var result := ResourceSaver.save(pending_resources[path], path)
			if result != OK:
				error = "Cannot save workspace resource: " + path + " (" + error_string(result) + ")"
				break
			pending_resources.erase(path)
	if error.is_empty():
		var data: Dictionary = workspace.manifest()
		if data.is_empty(): error = workspace.error
		else:
			if not version.text.strip_edges().is_empty(): data.version = version.text.strip_edges()
			else: data.erase("version")
			if not workspace.save(data): error = workspace.error
	busy = false
	invalidate()
	refresh()
	reported.emit("Workspace saved: " + target if error.is_empty() else error)
	return error.is_empty()

func read_history() -> void:
	var state := State.new()
	history = state.read(workspace.root, false)
	history_error = state.error

func export_current() -> void:
	read_history()
	if not history_error.is_empty(): reported.emit(history_error); return
	var destination: String = history.get("export_path", "")
	if destination.is_empty(): choose_export()
	else: await write_export(destination, false)

func choose_export() -> void:
	if busy: return
	read_history()
	if not history_error.is_empty(): reported.emit(history_error); return
	export_dialog.current_path = history.get("export_path", "")
	if export_dialog.current_path.is_empty():
		var default_path := ProjectSettings.globalize_path("res://../../../build/mod-exports/" + workspace.root.get_file() + ".zip")
		export_dialog.current_path = EditorInterface.get_editor_settings().get_project_metadata("mgs_visuals", "export:" + workspace.root, default_path)
	export_dialog.popup_centered_ratio(0.7)

func write_export(destination: String, explicit_destination: bool) -> void:
	if busy or export_progress.running: return
	export_progress.begin()
	await get_tree().process_frame
	if not await save_workspace():
		export_progress.finish()
		return
	busy = true
	status_check.cancel()
	var error := await export_progress.export_workspace(workspace.root, destination, explicit_destination)
	busy = false
	invalidate()
	refresh()
	reported.emit("Exported " + ProjectSettings.globalize_path(destination) if error.is_empty() else error)

func choose_fork() -> void:
	if busy: return
	var data: Dictionary = workspace.manifest()
	fork_name.text = str(data.get("name", data.get("id", "New mod"))) + " copy"
	fork_id.text = str(data.get("id", "local.visuals")) + ".copy"
	fork_dialog.popup_centered(Vector2i(460, 170))

func fork_workspace() -> void:
	if not await save_workspace(): return
	var repository := ProjectSettings.globalize_path("res://../../..")
	var preparation := preload("res://addons/mgs_editor/sdk_paths.gd").prepare_python()
	if not preparation.is_empty():
		reported.emit(preparation)
		return
	var python := preload("res://addons/mgs_editor/sdk_paths.gd").python()
	var output: Array = []
	var destination := "res://mods/" + fork_id.text.strip_edges()
	var result := OS.execute(python, [repository.path_join("tools/fork_godot_mod.py"),
		ProjectSettings.globalize_path(workspace.root), ProjectSettings.globalize_path(destination),
		ProjectSettings.globalize_path("res://"), fork_id.text.strip_edges(), fork_name.text,
		"--godot", OS.get_executable_path()], output, true)
	if result != 0:
		reported.emit("Cannot create mod copy: " + "\n".join(output))
		return
	var filesystem := EditorInterface.get_resource_filesystem()
	filesystem.scan()
	await get_tree().process_frame
	while filesystem.is_scanning(): await get_tree().process_frame
	selected.emit(destination)
	reported.emit("Created independent mod: " + destination)

func _exit_tree() -> void:
	status_check.cancel()
	if status_check.worker.is_started(): status_check.finish()
