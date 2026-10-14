@tool
extends EditorPlugin

const Paths = preload("res://addons/mgs_editor/sdk_paths.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func sdk_plugin(node: Node) -> Node:
	var script := node.get_script() as Script
	if script != null and script.resource_path == "res://addons/mgs_editor/plugin.gd": return node
	for child in node.get_children():
		var result := sdk_plugin(child)
		if result != null: return result
	return null

func wait_native(session: Node, terminal: String) -> Dictionary:
	var deadline := Time.get_ticks_msec() + 90000
	while Time.get_ticks_msec() < deadline:
		var path: String = session.directory.path_join("status.json")
		if FileAccess.file_exists(path):
			var status = JSON.parse_string(FileAccess.get_file_as_string(path))
			if status is Dictionary and status.get("state") in [terminal, "failed"]: return status
		await get_tree().create_timer(0.2).timeout
	return {"state":"timeout"}

func fresh_reopen(archive: String) -> void:
	var output: Array = []
	var code := OS.execute(Paths.python(), [Paths.root().path_join("tools/import_godot_mod.py"), archive,
		Paths.root().path_join("build/sdk-reopened"), "--godot", OS.get_executable_path(),
		"--project", ProjectSettings.globalize_path("res://")], output, true)
	check(code == 0, "Fresh SDK ZIP import failed: " + str(output))
	if code != 0: return
	var response = JSON.parse_string("\n".join(output))
	var scene := load(str(response.path).path_join("marker.tscn")) as PackedScene
	check(scene != null, "Freshly reopened scene could not load")
	if scene == null: return
	var reopened := scene.instantiate()
	check(reopened.get_node("Marker").get("finish") == "teal", "Fresh ZIP lost edited Inspector value")
	check(not reopened.has_node("_MapSession"), "Local map preview was serialized into the ZIP")
	reopened.free()

func settle_editor() -> void:
	while EditorInterface.get_resource_filesystem().is_scanning(): await get_tree().process_frame
	var sdk := sdk_plugin(get_tree().root)
	while sdk != null and sdk.catalog_loading: await get_tree().process_frame
	await get_tree().create_timer(3).timeout

func run() -> void:
	await settle_editor()
	var sdk := sdk_plugin(get_tree().root)
	check(sdk != null and Paths.packaged(), "SDK editor plugin or packaged tool paths unavailable")
	if sdk == null:
		get_tree().quit(1)
		return
	var archive := Paths.root().path_join("build/mod-exports/sdk-named-resources.zip")
	var before := FileAccess.get_sha256(archive)
	await sdk.picker.open_zip(archive)
	await settle_editor()
	var scene := EditorInterface.get_edited_scene_root()
	check(scene != null and scene.has_node("Marker"), "Open ZIP did not open the sample scene: " + sdk.status.text)
	if scene == null or not scene.has_node("Marker"):
		get_tree().quit(1)
		return
	check(scene.has_node("_MapSession") and scene.find_children("*", "MeshInstance3D", true, false).size() > 20,
		"Prepared original map preview did not load in the editor")
	scene.get_node("Marker").set("finish", "teal")
	EditorInterface.mark_scene_as_unsaved()
	check(await sdk.workspace_actions.save_workspace(), "SDK Save failed")
	await settle_editor()
	sdk.workspace_actions.fork_id.text = "sdk.relocation.proof"
	sdk.workspace_actions.fork_name.text = "Relocated SDK proof"
	await sdk.workspace_actions.fork_workspace()
	await settle_editor()
	check(sdk.workspace.root == "res://mods/sdk.relocation.proof", "SDK Save As did not select the new mod: " + sdk.status.text)
	var edited := Paths.root().path_join("build/mod-exports/sdk-edited.zip")
	await sdk.workspace_actions.write_export(edited, true)
	check(FileAccess.file_exists(edited), "SDK Export failed: " + sdk.status.text)
	if FileAccess.file_exists(edited): fresh_reopen(edited)
	sdk.run_native_map()
	var started := await wait_native(sdk.native_test, "running")
	check(started.state == "running", "SDK native run failed: " + str(started))
	var log_path: String = sdk.native_test.directory.path_join("godot.log")
	await get_tree().create_timer(8).timeout
	sdk.native_test.stop()
	var stopped := await wait_native(sdk.native_test, "stopped")
	check(stopped.state == "stopped" and not str(stopped.get("message", "")).contains("forced"), "SDK native stop failed: " + str(stopped))
	var deadline := Time.get_ticks_msec() + 10000
	while sdk.native_test.active() and Time.get_ticks_msec() < deadline: await get_tree().create_timer(0.1).timeout
	check(not sdk.native_test.active(), "SDK native child survived shutdown")
	check("[loading] s00a:" in FileAccess.get_file_as_string(sdk.native_test.directory.path_join("runner.log")), "Native run stopped before the dock finished loading")
	check("MGS_NAMED_RESOURCE mod=sdk.relocation.proof finish=teal" in FileAccess.get_file_as_string(log_path), "Native run did not load the edited material")
	check(FileAccess.get_sha256(archive) == before, "Editing overwrote the original example ZIP")
	print("MGS_SDK_EDITOR_TEST failures=%d native_logs=%s" % [failures, sdk.native_test.directory])
	get_tree().quit(1 if failures else 0)

func _enter_tree() -> void:
	run.call_deferred()
