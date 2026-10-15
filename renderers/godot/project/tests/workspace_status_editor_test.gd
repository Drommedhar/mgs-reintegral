@tool
extends EditorPlugin

const State = preload("res://addons/mgs_editor/workspace_state.gd")
var failures := 0
var panel: VBoxContainer
var max_refresh_ms := 0.0

func check(value: bool, message: String) -> void:
	if value: return
	failures += 1
	push_error(message)

func find_sdk(node: Node) -> Node:
	var script := node.get_script() as Script
	if script != null and script.resource_path == "res://addons/mgs_editor/plugin.gd": return node
	for child in node.get_children():
		var found := find_sdk(child)
		if found != null: return found
	return null

func settle() -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while panel.dirty or panel.status_check.worker.is_started():
		var started := Time.get_ticks_usec()
		panel.refresh()
		max_refresh_ms = maxf(max_refresh_ms, (Time.get_ticks_usec() - started) / 1000.0)
		await get_tree().process_frame
		if Time.get_ticks_msec() >= deadline:
			check(false, "Workspace status did not settle")
			return

func run() -> void:
	while EditorInterface.get_resource_filesystem().is_scanning(): await get_tree().process_frame
	var sdk := find_sdk(get_tree().root)
	check(sdk != null, "SDK plugin is missing")
	if sdk == null: get_tree().quit(1); return
	while sdk.catalog_loading: await get_tree().process_frame
	panel = sdk.workspace_actions
	var workspace := preload("res://addons/mgs_editor/mod_workspace.gd").new()
	workspace.root = "res://mods/status.test"
	check(workspace.save({"schema":1, "id":"status.test", "resources":{"data":{"path":"data.bin"}}}), workspace.error)
	var block := PackedByteArray()
	block.resize(1024 * 1024)
	block.fill(42)
	var data := FileAccess.open(workspace.root.path_join("data.bin"), FileAccess.WRITE)
	for index in 128: data.store_buffer(block)
	data.close()
	var destination := "user://workspace-status-editor.zip"
	check(State.new().export_zip(workspace.root, destination, true).is_empty(), "Cannot export status fixture")
	var started := Time.get_ticks_usec()
	sdk.select_workspace(workspace.root, false)
	var activate_ms := (Time.get_ticks_usec() - started) / 1000.0
	check(panel.history.export_path == ProjectSettings.globalize_path(destination), "Destination unavailable during background check")
	await settle()
	check(panel.summary.text.begins_with("Workspace matches exported ZIP"), "Fresh export status mismatch: " + panel.summary.text)
	var material := StandardMaterial3D.new()
	var path: String = workspace.root.path_join("paint.tres")
	check(ResourceSaver.save(material, path) == OK, "Cannot save material fixture")
	material.take_over_path(path)
	check(workspace.register_resource("paint", path), workspace.error)
	var filesystem := EditorInterface.get_resource_filesystem()
	filesystem.filesystem_changed.emit()
	await settle()
	check(panel.summary.text.begins_with("Saved changes not exported"), "Filesystem change did not update status")
	check(State.new().export_zip(workspace.root, destination, true).is_empty(), "Cannot update export fixture")
	panel.invalidate()
	await settle()
	check(panel.summary.text.begins_with("Workspace matches exported ZIP"), "Updated export remains dirty")
	EditorInterface.edit_resource(material)
	await get_tree().process_frame
	material.albedo_color = Color.RED
	EditorInterface.get_inspector().property_edited.emit("albedo_color")
	panel.refresh()
	check(panel.summary.text.begins_with("Unsaved workspace changes"), "Inspector edit did not show unsaved status")
	check(await panel.save_workspace(), "Workspace save failed")
	await settle()
	check(panel.summary.text.begins_with("Saved changes not exported"), "Saved material edit was missed")
	panel.invalidate()
	panel.refresh()
	sdk.select_workspace("res://mods/local", false)
	await settle()
	check(panel.history.get("export_path", "").is_empty(), "Old workspace result overwrote the new workspace")
	check(panel.summary.text.begins_with("Not exported yet"), "New workspace inherited the old status")
	sdk.select_workspace(workspace.root, false)
	panel.invalidate()
	panel.refresh()
	started = Time.get_ticks_usec()
	panel.status_check.cancel()
	panel.status_check.finish()
	var cancel_ms := (Time.get_ticks_usec() - started) / 1000.0
	check(activate_ms < 200.0 and max_refresh_ms < 200.0 and cancel_ms < 200.0, "Editor status blocks the main thread")
	print("MGS_WORKSPACE_STATUS_TIMING activate_ms=%.3f max_refresh_ms=%.3f cancel_ms=%.3f" % [activate_ms, max_refresh_ms, cancel_ms])
	DirAccess.remove_absolute(destination)
	print("MGS_WORKSPACE_STATUS_EDITOR_TEST failures=%d" % failures)
	get_tree().quit(1 if failures else 0)

func _enter_tree() -> void:
	run.call_deferred()
