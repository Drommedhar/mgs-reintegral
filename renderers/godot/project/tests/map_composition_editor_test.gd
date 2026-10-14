@tool
extends EditorPlugin

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func find_sdk(node: Node) -> Node:
	if node.get_script() != null and node.get_script().resource_path == "res://addons/mgs_editor/plugin.gd": return node
	for child in node.get_children():
		var result := find_sdk(child)
		if result != null: return result
	return null

func settle() -> void:
	while EditorInterface.get_resource_filesystem().is_scanning(): await get_tree().process_frame
	var sdk := find_sdk(get_tree().root)
	while sdk != null and sdk.catalog_loading: await get_tree().process_frame
	await get_tree().create_timer(3).timeout

func select_stage(item: TreeItem, stage: String) -> bool:
	for child in item.get_children():
		var entry: Dictionary = child.get_metadata(0)
		if entry.get("stage") == stage and not entry.has("clip") and int(entry.get("source", {}).get("disc", 0)) == 1:
			child.select(0)
			return true
		if select_stage(child, stage): return true
	return false

func open_map(sdk: Node, stage: String) -> Node:
	sdk.stages.search.text = stage
	sdk.stages.populate()
	check(select_stage(sdk.stages.list.get_root(), stage), "Map browser does not list " + stage)
	check(sdk.stages.selected().get("stage") == stage, "Map browser did not select %s: %s" % [stage, sdk.stages.selected()])
	sdk.create_stage()
	await settle()
	return EditorInterface.get_edited_scene_root()

func run() -> void:
	await settle()
	var sdk := find_sdk(get_tree().root)
	check(sdk != null, "SDK editor plugin is unavailable")
	if sdk == null:
		get_tree().quit(1)
		return
	var workspace := "res://mods/test.map-composition"
	sdk.picker.select(workspace, false)
	var data: Dictionary = sdk.workspace.manifest()
	data.id = "test.map-composition"
	check(sdk.workspace.save(data), "Cannot save editor fixture workspace")
	sdk.refresh_mod_views(data)
	var parent := await open_map(sdk, "s00a")
	check(parent != null and parent.has_node("_MapSession"), "Editor did not create the original map: " + sdk.status.text)
	if parent == null or not parent.has_node("_MapSession"):
		get_tree().quit(1)
		return
	var light := OmniLight3D.new()
	light.name = "AuthoredLight"
	light.position = Vector3(1, 3, 2)
	light.light_energy = 2.75
	parent.add_child(light)
	light.owner = parent
	parent.get_node("MapEnvironment").environment.ambient_light_energy = 1.25
	parent.get_node("LocalMapReference").get_child(0).hide()
	EditorInterface.mark_scene_as_unsaved()
	check(await sdk.workspace_actions.save_workspace(), "Cannot save parent map")
	var original_target: String = parent.get_meta("mgs_removals")[0].asset
	check(sdk.catalog[original_target].sha256 != sdk.catalog[original_target.replace("/s00a/", "/d00a/")].sha256, "Real-disc fixture requires distinct gameplay/cinematic map revisions")
	data = sdk.workspace.manifest()
	data.stages["disc1/s00a"].original_lighting = true
	check(sdk.workspace.save(data), "Cannot save inherited lighting setting")
	var parent_path: String = parent.scene_file_path
	var parent_hash := FileAccess.get_sha256(parent_path)
	sdk.refresh_mod_views(data)
	var variant := await open_map(sdk, "d00a")
	check(variant != null and variant.has_node("AuthoredLight"), "Opening inherited map discarded authored additions: " + sdk.status.text)
	if variant == null or not variant.has_node("AuthoredLight"):
		get_tree().quit(1)
		return
	check(variant.get_node("AuthoredLight").position == Vector3(1, 3, 2), "Inherited map changed authored placement")
	check(is_equal_approx(variant.get_node("MapEnvironment").environment.ambient_light_energy, 1.25), "Inherited map lost its environment")
	check(variant.get_meta("mgs_scene_source").stage == "d00a", "Variant source fingerprint was not updated")
	check(sdk.workspace.manifest().stages["disc1/d00a"].original_lighting, "Variant lost the inherited lighting mode")
	check(FileAccess.get_sha256(parent_path) == parent_hash, "Creating a variant modified its parent scene")
	var rules: Array = variant.get_meta("mgs_removals")
	check(rules.size() == 1 and rules[0].asset == original_target.replace("/s00a/", "/d00a/"), "Whole-model hide did not follow the declared cinematic variant")
	var destination := ProjectSettings.globalize_path("res://../../../map-composition.zip")
	await sdk.workspace_actions.write_export(destination, true)
	var archive := ZIPReader.new()
	check(archive.open(destination) == OK, "Editor export failed")
	check(Array(archive.get_files()).filter(func(name): return not name.ends_with("/")).size() == 3, "Editor ZIP included files besides manifest and two authored scenes")
	for name in archive.get_files():
		if name.ends_with(".tscn"):
			check(not "metadata/mgs_asset_id" in archive.read_file(name).get_string_from_utf8(), "Original preview entered the editor ZIP")
	archive.close()
	await settle()
	print("MGS_MAP_COMPOSITION_EDITOR_TEST failures=%d" % failures)
	get_tree().quit(1 if failures else 0)

func _enter_tree() -> void:
	run.call_deferred()
