@tool
extends EditorPlugin

const Paths = preload("res://addons/mgs_editor/sdk_paths.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func settle() -> void:
	while EditorInterface.get_resource_filesystem().is_scanning(): await get_tree().process_frame
	for frame in 5: await get_tree().process_frame

func run() -> void:
	await settle()
	var sdk: EditorPlugin
	for candidate in get_tree().root.find_children("*", "EditorPlugin", true, false):
		if candidate.get_script() != null and candidate.get_script().resource_path == "res://addons/mgs_editor/plugin.gd": sdk = candidate
	check(sdk != null, "Packaged editor plugin did not load")
	if sdk == null:
		get_tree().quit(1)
		return
	while sdk.catalog_loading: await get_tree().process_frame
	var catalog := Paths.root().path_join(".local/godot-content/catalog.json")
	DirAccess.make_dir_recursive_absolute(catalog.get_base_dir())
	var sample := catalog.get_base_dir().path_join("sample.bin")
	FileAccess.open(sample, FileAccess.WRITE).store_string("synthetic provenance fixture")
	var digest := FileAccess.get_sha256(sample)
	FileAccess.open(catalog, FileAccess.WRITE).store_string(JSON.stringify({"schema":1,
		"assets":{"fixture":{"sha256":digest, "preparedFiles":{"sample.bin":digest}}}}))
	check(not FileAccess.file_exists(Paths.python()), "First editor operation must start without Python")
	await sdk.picker.open_zip(Paths.root().path_join("fixture.zip"))
	await settle()
	check(sdk.workspace.manifest().get("id") == "test.release", "Open ZIP did not select the imported mod: " + sdk.status.text)
	if sdk.workspace.manifest().get("id") != "test.release":
		get_tree().quit(1)
		return
	check(FileAccess.file_exists(Paths.python()), "Open ZIP did not install Python")
	check(DirAccess.rename_absolute(Paths.python(), Paths.python() + ".broken") == OK, "Cannot simulate incomplete Python installation")
	sdk.workspace_actions.fork_id.text = "test.release.copy"
	sdk.workspace_actions.fork_name.text = "Release copy"
	await sdk.workspace_actions.fork_workspace()
	await settle()
	check(sdk.workspace.root == "res://mods/test.release.copy", "Save As did not select the new workspace: " + sdk.status.text)
	check(FileAccess.file_exists(Paths.python()), "Save As did not repair Python")
	check(FileAccess.file_exists("res://mods/test.release.copy/scene.tscn"), "Save As lost authored scene")
	print("MGS_SDK_DOWNLOAD_EDITOR_TEST failures=%d" % failures)
	get_tree().quit(1 if failures else 0)

func _enter_tree() -> void:
	run.call_deferred()
