@tool
extends "res://tests/map_composition_editor_test.gd"

const Authoring = preload("res://addons/mgs_editor/map_authoring.gd")
const Registry = preload("res://mod_registry.gd")
const MapEnvironment = preload("res://map_environment.gd")
const Profile = preload("res://mod_profile.gd")

func add_marker(node: Node3D, title: String, energy: float, directory: String) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = title
	mesh.mesh = BoxMesh.new()
	mesh.position = Vector3(1 if title == "OwnMarker" else 2, 1, 1)
	node.add_child(mesh)
	mesh.owner = node
	MapEnvironment.attach(node).environment.ambient_light_energy = energy
	var path := directory.path_join("behavior.gd")
	FileAccess.open(path, FileAccess.WRITE).store_string('''extends Node3D
func _ready():
	verify.call_deferred()
func verify():
	var data := {"mod":get_meta("mgs_mod_package"), "ambient":get_world_3d().environment.ambient_light_energy}
	var path := OS.get_environment("MGS_GODOT_READY_FILE").get_base_dir().path_join("profile-" + str(data.mod) + ".json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	print("MGS_PROFILE_PROOF mod=%s ambient=%.1f" % [data.mod, data.ambient])
''')
	node.set_script(load(path))

func preview_check(sdk: Node, energy: float, foreign: bool) -> void:
	var node := EditorInterface.get_edited_scene_root()
	check(node.get_meta("mgs_profile_preview", false), "Profile preview did not open as a separate editor scene: " + sdk.status.text)
	if not node.get_meta("mgs_profile_preview", false): return
	check(node.find_children("OwnMarker", "MeshInstance3D", true, false).size() == 1, "Profile preview lost or duplicated the active mod")
	check(node.find_children("ForeignMarker", "MeshInstance3D", true, false).size() == int(foreign), "Enabled profile did not control other mod additions")
	var environment := MapEnvironment.find_in(node)
	check(environment != null and is_equal_approx(environment.environment.ambient_light_energy, energy), "Editor preview resolved a different environment winner")
	var packed := PackedScene.new()
	check(packed.pack(node) == OK and packed.get_state().get_node_count() == 1, "Saving the editor preview would include mod/original content")

func wait_native(sdk: Node, expected: String) -> Dictionary:
	var deadline := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < deadline:
		var path: String = sdk.native_test.directory.path_join("status.json")
		if FileAccess.file_exists(path):
			var state = JSON.parse_string(FileAccess.get_file_as_string(path))
			if state is Dictionary and state.get("state") in [expected, "failed"]: return state
		await get_tree().create_timer(0.1).timeout
	return {"state":"timeout", "message":sdk.test_status.text}

func native_proof(sdk: Node) -> void:
	sdk.run_native_map()
	var state := await wait_native(sdk, "running")
	check(state.state == "running", "Editor could not start the enabled native profile: " + JSON.stringify(state))
	var directory: String = sdk.native_test.directory
	var deadline := Time.get_ticks_msec() + 30000
	var observed: Dictionary = {}
	while state.state == "running" and Time.get_ticks_msec() < deadline:
		for identity in ["test.profile.active", "test.profile.context"]:
			var path := directory.path_join("profile-" + identity + ".json")
			if FileAccess.file_exists(path): observed[identity] = JSON.parse_string(FileAccess.get_file_as_string(path))
		if observed.size() == 2: break
		await get_tree().create_timer(0.1).timeout
	check(observed.size() == 2 and observed.values().all(func(proof): return proof is Dictionary and is_equal_approx(proof.ambient, 1.8)), "Native Run did not use the editor profile's additions and environment")
	var snapshot := Profile.new()
	check(snapshot.read(directory.path_join("mod-profile.json")).is_empty() and snapshot.paths().size() == 2, "Native test did not record the exact enabled profile")
	sdk.native_test.stop()
	state = await wait_native(sdk, "stopped")
	check(state.state == "stopped" and not "forced" in state.get("message", ""), "Native profile did not stop cleanly: " + JSON.stringify(state))
	deadline = Time.get_ticks_msec() + 10000
	while sdk.native_test.active() and Time.get_ticks_msec() < deadline: await get_tree().create_timer(0.1).timeout
	check(not sdk.native_test.active(), "Native profile process survived Stop")
	check(FileAccess.get_file_as_string(directory.path_join("godot.err")).is_empty(), "Native profile emitted renderer errors")
	print("MGS_PROFILE_NATIVE_LOGS " + directory)

func run() -> void:
	await settle()
	var sdk := find_sdk(get_tree().root)
	check(sdk != null, "SDK editor plugin is unavailable")
	if sdk == null:
		get_tree().quit(1)
		return
	var workspace := "res://mods/test.profile.active"
	sdk.picker.select(workspace, false)
	var data: Dictionary = sdk.workspace.manifest()
	data.id = "test.profile.active"
	check(sdk.workspace.save(data), "Cannot save active fixture workspace")
	sdk.refresh_mod_views(data)
	var authored := await open_map(sdk, "s00a")
	check(authored != null and authored.has_node("_MapSession"), "Cannot create active map: " + sdk.status.text)
	if authored == null or not authored.has_node("_MapSession"):
		get_tree().quit(1)
		return
	add_marker(authored, "OwnMarker", 1.1, workspace)
	EditorInterface.mark_scene_as_unsaved()
	check(await sdk.workspace_actions.save_workspace(), "Cannot save active additions")
	var context := "res://mods/test.profile.context"
	DirAccess.make_dir_recursive_absolute(context)
	var other := Authoring.new().create_map(Registry.new(), sdk.content, "s00a", 1)
	add_marker(other, "ForeignMarker", 1.8, context)
	check(sdk.write_scene(other, context.path_join("map.tscn")), "Cannot save context map")
	other.free()
	var manifest := context.path_join("mod.json")
	FileAccess.open(manifest, FileAccess.WRITE).store_string(JSON.stringify({"schema":1,"id":"test.profile.context","priority":200,"stages":{"disc1/s00a":{"scene":"map.tscn"}}}))
	var foreign_hash := FileAccess.get_sha256(manifest)
	var active_hash := FileAccess.get_sha256(workspace.path_join("mod.json"))
	EditorInterface.get_resource_filesystem().scan()
	await settle()
	var controls: Node = sdk.mod_profile_editor
	controls.add_manifest(manifest)
	check(controls.profile.entries.size() == 2, "Enabled list omitted or duplicated a workspace")
	sdk.preview_profile()
	await settle()
	preview_check(sdk, 1.8, true)
	check("test.profile.context" in controls.diagnostics.text and "world environment" in controls.diagnostics.text, "Editor did not show the competing setting and winner")
	controls.update_entry(0, true, 300)
	preview_check(sdk, 1.1, true)
	controls.update_entry(1, false, 200)
	preview_check(sdk, 1.1, false)
	controls.update_entry(1, true, 400)
	preview_check(sdk, 1.8, true)
	check(FileAccess.get_sha256(manifest) == foreign_hash and FileAccess.get_sha256(workspace.path_join("mod.json")) == active_hash, "Priority controls rewrote a source mod manifest")
	await native_proof(sdk)
	var destination := ProjectSettings.globalize_path("res://../../../profile-active.zip")
	await sdk.workspace_actions.write_export(destination, true)
	var archive := ZIPReader.new()
	check(archive.open(destination) == OK, "Active workspace did not export from Profile Preview")
	var files := Array(archive.get_files()).filter(func(path): return not path.ends_with("/"))
	check(files.size() == 3, "Profile export included files beyond active manifest, scene and script")
	for path in files:
		if path.ends_with(".tscn"):
			var text := archive.read_file(path).get_string_from_utf8()
			check("OwnMarker" in text and not "ForeignMarker" in text and not "metadata/mgs_asset_id" in text, "Profile preview contaminated active export")
	archive.close()
	await sdk.picker.open_zip(destination)
	await settle()
	check(EditorInterface.get_edited_scene_root().has_node("OwnMarker") and not EditorInterface.get_edited_scene_root().has_node("ForeignMarker"), "Reopening ZIP did not restore only the active editable scene")
	check(FileAccess.get_sha256(manifest) == foreign_hash, "Export/reopen modified the context mod")
	var alternate := "res://mods/test.profile.alternate"
	DirAccess.make_dir_recursive_absolute(alternate)
	FileAccess.open(alternate.path_join("mod.json"), FileAccess.WRITE).store_string('{"schema":1,"id":"test.profile.active","stages":{}}')
	sdk.picker.select(alternate, false)
	check(controls.profile.paths().size() == 2 and workspace.path_join("mod.json") not in controls.profile.paths() and alternate.path_join("mod.json") in controls.profile.paths(), "Switching to another workspace for the same mod left both versions enabled")
	print("MGS_MOD_PROFILE_EDITOR_TEST failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
