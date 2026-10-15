@tool
extends EditorPlugin

var failures := 0
var complete := false
var frames := 0
var longest_frame_ms := 0.0
var previous_tick := 0
var panel: VBoxContainer
var phases := {}
var percentages: Array[float] = []
var progress_frames := 0
var messages: Array[String] = []

func check(value: bool, message: String) -> void:
	if value: return
	failures += 1
	push_error(message)

func frame() -> void:
	if complete: return
	var tick := Time.get_ticks_usec()
	if previous_tick: longest_frame_ms = maxf(longest_frame_ms, (tick - previous_tick) / 1000.0)
	previous_tick = tick
	frames += 1
	if panel.export_progress.visible:
		progress_frames += 1
		phases[panel.export_progress.phase] = true
		if not panel.export_progress.bar.indeterminate:
			percentages.append(panel.export_progress.bar.value)

func export(panel: Node, destination: String) -> void:
	complete = false
	previous_tick = 0
	await panel.write_export(destination, true)
	complete = true

func wait_export() -> void:
	var deadline := Time.get_ticks_msec() + 30000
	while not complete and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	check(complete, "Export did not finish")

func cancellation(destination: String, history_path: String) -> void:
	var before_zip := FileAccess.get_sha256(destination)
	var before_history := FileAccess.get_sha256(history_path)
	export(panel, destination)
	while not complete and panel.export_progress.phase != "compressing": await get_tree().process_frame
	check(not complete, "Export finished before cancellation could be tested")
	panel.export_progress.cancel()
	await wait_export()
	check(messages.back() == "Export cancelled.", "Cancel was not reported: " + messages.back())
	check(FileAccess.get_sha256(destination) == before_zip, "Cancelled export replaced the previous ZIP")
	check(FileAccess.get_sha256(history_path) == before_history, "Cancelled export replaced history")
	var leftovers := Array(DirAccess.get_files_at(destination.get_base_dir())).filter(func(path): return path.begins_with(destination.get_file() + ".") and path.ends_with(".tmp"))
	check(leftovers.is_empty(), "Cancelled export left a partial archive")

func failed_export(workspace: RefCounted, destination: String) -> void:
	var before := FileAccess.get_sha256(destination)
	var path: String = workspace.root.path_join("original.tres")
	FileAccess.open(path, FileAccess.WRITE).store_string('[gd_resource type="StandardMaterial3D" format=3]\n[resource]\nmetadata/mgs_retail_derived = true\n')
	check(workspace.register_resource("original", path), workspace.error)
	export(panel, destination)
	await wait_export()
	check("original" in messages.back(), "Export lost original-content validation")
	check(FileAccess.get_sha256(destination) == before, "Failed export damaged the previous ZIP")
	check(workspace.remove_resource("original"), workspace.error)

func stopped_worker(destination: String) -> void:
	var before := FileAccess.get_sha256(destination)
	export(panel, destination)
	while not complete and panel.export_progress.pid <= 0: await get_tree().process_frame
	check(not complete and OS.kill(panel.export_progress.pid) == OK, "Cannot stop fixture worker")
	await wait_export()
	check("stopped unexpectedly" in messages.back(), "Worker failure was not reported")
	check(FileAccess.get_sha256(destination) == before, "Stopped worker damaged the previous ZIP")

func closed_dialog(workspace: RefCounted, destination: String) -> void:
	var before := FileAccess.get_sha256(destination)
	var dialog := preload("res://addons/mgs_editor/export_progress.gd").new()
	add_child(dialog)
	dialog.begin()
	check(dialog.launch(workspace.root, destination, true).is_empty(), "Cannot start teardown fixture")
	var deadline := Time.get_ticks_msec() + 10000
	while OS.is_process_running(dialog.pid) and Time.get_ticks_msec() < deadline:
		dialog.heartbeat()
		if dialog.read_status().get("phase") == "compressing": break
		await get_tree().process_frame
	var child: int = dialog.pid
	check(OS.is_process_running(child), "Teardown fixture finished before cancellation")
	dialog.queue_free()
	while OS.is_process_running(child) and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	check(not OS.is_process_running(child), "Worker survived dialog teardown")
	check(FileAccess.get_sha256(destination) == before, "Teardown replaced the previous ZIP")

func run() -> void:
	while EditorInterface.get_resource_filesystem().is_scanning(): await get_tree().process_frame
	get_tree().root.gui_embed_subwindows = true
	get_tree().root.size = Vector2i(1280, 720)
	var workspace := preload("res://addons/mgs_editor/mod_workspace.gd").new()
	workspace.root = "res://mods/export.test"
	check(workspace.save({"schema":1, "id":"export.test", "resources":{"payload":{"path":"payload.bin"}}}), workspace.error)
	var block := PackedByteArray()
	block.resize(1024 * 1024)
	block.fill(65)
	var file := FileAccess.open(workspace.root.path_join("payload.bin"), FileAccess.WRITE)
	for index in 128: file.store_buffer(block)
	file.close()
	panel = preload("res://addons/mgs_editor/workspace_actions.gd").new()
	panel.workspace = workspace
	panel.reported.connect(func(message): messages.append(message))
	add_child(panel)
	panel.activate()
	await get_tree().process_frame
	get_tree().process_frame.connect(frame)
	var destination := ProjectSettings.globalize_path("res://../../../export-test.zip")
	var started := Time.get_ticks_usec()
	export(panel, destination)
	var dispatch_ms := (Time.get_ticks_usec() - started) / 1000.0
	await panel.write_export(destination + ".duplicate.zip", true)
	await wait_export()
	await get_tree().process_frame
	check(dispatch_ms < 200.0, "ZIP export blocked its editor callback")
	check(frames > 3 and longest_frame_ms < 500.0, "Editor stopped drawing during ZIP export")
	check(panel.has_node("ExportProgress"), "ZIP export has no progress dialog")
	check(FileAccess.file_exists(destination), "ZIP was not exported")
	check(not FileAccess.file_exists(destination + ".duplicate.zip"), "Duplicate export was started")
	check(progress_frames > 3 and phases.has("compressing") and phases.has("catalogs"), "Export progress did not remain visible across phases")
	check(percentages.size() > 2 and percentages.max() > percentages.min(), "Compression progress did not advance")
	var archive := ZIPReader.new()
	check(archive.open(destination) == OK, "Cannot open exported ZIP")
	var bytes := archive.read_file("payload.bin")
	check(bytes.size() == 128 * 1024 * 1024 and bytes.count(65) == bytes.size(), "Chunked ZIP writing damaged the payload")
	archive.close()
	await cancellation(destination, workspace.root.path_join(".editor-workspace.json"))
	await failed_export(workspace, destination)
	await stopped_worker(destination)
	await closed_dialog(workspace, destination)
	print("MGS_WORKSPACE_EXPORT_TIMING dispatch_ms=%.3f frames=%d max_frame_ms=%.3f" % [dispatch_ms, frames, longest_frame_ms])
	print("MGS_WORKSPACE_EXPORT_EDITOR_TEST failures=%d" % failures)
	get_tree().quit(1 if failures else 0)

func _enter_tree() -> void:
	run.call_deferred()
