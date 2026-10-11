@tool
extends EditorPlugin

const MapAuthoring = preload("res://addons/mgs_editor/map_authoring.gd")
const ModExport = preload("res://addons/mgs_editor/mod_export.gd")
const DiscMap = preload("res://addons/mgs_editor/disc_map.gd")
const Coordinates = preload("res://map_coordinates.gd")
const MapLights = preload("res://map_lights.gd")
const EventLightTemplates = preload("res://event_light_templates.gd")
const ModWorkspace = preload("res://addons/mgs_editor/mod_workspace.gd")
const WorkspacePicker = preload("res://addons/mgs_editor/workspace_picker.gd")
const AssetAuthoring = preload("res://addons/mgs_editor/asset_authoring.gd")
var map_authoring := MapAuthoring.new()
var workspace := ModWorkspace.new()
var asset_authoring := AssetAuthoring.new()
var picker: VBoxContainer
var asset_dialog := EditorFileDialog.new()
var export_dialog := EditorFileDialog.new()
var pending_asset := ""
var panel: VBoxContainer
var status: Label
var search: LineEdit
var assets: ItemList
var stages: OptionButton
var catalog: Dictionary = {}
var prepared: Dictionary = {}
var asset_root: String
var sessions: Array[Node] = []

func _enter_tree() -> void:
	panel = VBoxContainer.new()
	panel.name = "MGS Visuals"
	picker = WorkspacePicker.new()
	picker.selected.connect(select_workspace)
	picker.failed.connect(func(message): status.text = message)
	panel.add_child(picker)
	search = LineEdit.new()
	search.placeholder_text = "Filter stable asset IDs"
	search.text_changed.connect(populate)
	panel.add_child(search)
	assets = ItemList.new()
	assets.custom_minimum_size = Vector2(280, 280)
	assets.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(assets)
	button("Reload prepared catalog", load_catalog)
	button("Edit selected model / view texture", open_asset)
	button("Show selected model's textures", show_model_textures)
	button("Show original source file", show_source)
	button("Assign replacement texture / model…", choose_replacement)
	stages = OptionButton.new()
	stages.add_item("s00a — docks")
	stages.add_item("s01a — helipad")
	panel.add_child(stages)
	button("Open map", create_stage)
	button("Export mod ZIP (custom assets only)", export_mod)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(status)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, panel)
	asset_dialog.access = FileDialog.ACCESS_FILESYSTEM
	asset_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	asset_dialog.file_selected.connect(assign_replacement)
	panel.add_child(asset_dialog)
	export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_dialog.filters = PackedStringArray(["*.zip ; Mod ZIP"])
	export_dialog.file_selected.connect(write_export)
	panel.add_child(export_dialog)
	scene_changed.connect(scene_opened)
	scene_saved.connect(scene_written)
	get_editor_interface().get_selection().selection_changed.connect(select_original)
	load_catalog()

func button(text: String, callback: Callable) -> void:
	var control := Button.new()
	control.text = text
	control.pressed.connect(callback)
	panel.add_child(control)

func load_catalog() -> void:
	asset_root = ProjectSettings.globalize_path("res://../../../.local/godot-content")
	var path := asset_root.path_join("catalog.json")
	if not FileAccess.file_exists(path):
		status.text = "Run tools/prepare-godot-content.ps1 with your disc folder first."
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("schema") != 1:
		status.text = "Invalid prepared catalog. Re-run preparation."
		return
	prepared = parsed
	catalog = prepared.assets
	populate(search.text)
	status.text = "%d local models and textures. Active mod: %s" % [catalog.size(), workspace.root]

func populate(filter: String) -> void:
	assets.clear()
	for identity in catalog:
		if catalog[identity].kind in ["model", "texture"] and filter.to_lower() in str(identity).to_lower():
			var index := assets.add_item(identity)
			assets.set_item_metadata(index, identity)

func manifest() -> Dictionary:
	var data := workspace.manifest()
	if data.is_empty(): status.text = workspace.error
	return data

func save_manifest(data: Dictionary) -> bool:
	if not workspace.save(data):
		status.text = workspace.error
		return false
	get_editor_interface().get_resource_filesystem().scan()
	return true

func write_scene(node: Node3D, path: String) -> bool:
	var result := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if result != OK:
		status.text = "Cannot create mod folder: " + error_string(result)
		return false
	var packed := PackedScene.new()
	result = packed.pack(node)
	if result == OK: result = ResourceSaver.save(packed, path)
	if result != OK:
		status.text = "Cannot save scene: " + error_string(result)
		return false
	return true

func selected_asset() -> String:
	var selected := assets.get_selected_items()
	if selected.is_empty():
		status.text = "Select an original model in the Scene tree, or a model/texture in the catalog."
		return ""
	return assets.get_item_metadata(selected[0])

func open_asset() -> void:
	var identity := selected_asset()
	if identity.is_empty(): return
	if catalog[identity].kind == "texture":
		var path: String = workspace.replacement_path(identity)
		if path.is_empty(): path = asset_root.path_join(catalog[identity].path)
		var image := Image.load_from_file(path)
		if image == null:
			status.text = "Cannot load texture: " + path
			return
		get_editor_interface().edit_resource(ImageTexture.create_from_image(image))
		status.text = "Texture: " + identity + ". Use Assign replacement to import your PNG/WebP into this mod."
		return
	var path := asset_authoring.model_scene(workspace, identity)
	if path.is_empty():
		status.text = asset_authoring.error
		return
	get_editor_interface().get_resource_filesystem().scan()
	get_editor_interface().open_scene_from_path(path)
	status.text = "Edit mesh_NNN material properties in the Inspector. Original geometry stays local; saved changes belong to " + workspace.root

func choose_replacement() -> void:
	pending_asset = selected_asset()
	if pending_asset.is_empty(): return
	asset_dialog.filters = PackedStringArray(["*.png,*.webp ; Texture replacement"]) if catalog[pending_asset].kind == "texture" else PackedStringArray(["*.glb,*.gltf,*.tscn ; Rigged model (GLB is copied; glTF/TSCN must be inside the mod)"])
	asset_dialog.current_dir = ProjectSettings.globalize_path(workspace.root)
	asset_dialog.popup_centered_ratio(0.7)

func show_source() -> void:
	var identity := selected_asset()
	if not identity.is_empty(): OS.shell_show_in_file_manager(asset_root.path_join(catalog[identity].path))

func show_model_textures() -> void:
	var identity := selected_asset()
	if identity.is_empty() or catalog[identity].kind != "model": return
	var textures := asset_authoring.texture_ids(identity, catalog, asset_root)
	assets.clear()
	for texture in textures:
		var index := assets.add_item(texture)
		assets.set_item_metadata(index, texture)
	status.text = "%d textures used by %s. Select one to view or replace it." % [textures.size(), identity.get_file()]

func assign_replacement(path: String) -> void:
	if catalog[pending_asset].kind == "texture":
		if workspace.import_texture(pending_asset, path).is_empty():
			status.text = workspace.error
			return
	elif not asset_authoring.assign_model(workspace, pending_asset, path, asset_root.path_join(catalog[pending_asset].path)):
		status.text = asset_authoring.error
		return
	get_editor_interface().get_resource_filesystem().scan()
	status.text = "Replacement saved in " + workspace.root + ". Reopen the model/map to refresh its preview, then export the mod."

func select_original() -> void:
	var selected := get_editor_interface().get_selection().get_selected_nodes()
	if selected.size() != 1: return
	var node: Node = selected[0]
	while node != null:
		var identity: String = node.get_meta("mgs_asset_id", node.get_meta("mgs_model_reference", ""))
		if catalog.has(identity):
			search.text = identity
			populate(identity)
			assets.select(0)
			return
		node = node.get_parent()

func select_workspace(path: String, open_scene: bool) -> void:
	workspace.root = path
	var data := manifest()
	if data.is_empty(): return
	status.text = "Active mod: " + path
	if not open_scene: return
	var scenes: Array = data.get("stages", {}).values()
	if not scenes.is_empty(): get_editor_interface().open_scene_from_path(path.path_join(scenes[0].scene))

func create_stage() -> void:
	var stage := "s00a" if stages.selected == 0 else "s01a"
	var filename := "stages/" + stage + ".tscn"
	var data := manifest()
	if data.is_empty(): return
	filename = data.stages.get(stage, {}).get("scene", filename)
	var path := workspace.root.path_join(filename)
	if not FileAccess.file_exists(path):
		var root := Node3D.new()
		root.name = stage + "_visuals"
		root.set_meta("mgs_stage", stage)
		root.set_meta("mgs_removals", [])
		Coordinates.mark_editor(root)
		var saved := write_scene(root, path)
		root.free()
		if not saved: return
	if not data.stages.has(stage): data.stages[stage] = {"scene": filename, "original_lighting": false}
	if not save_manifest(data): return
	get_editor_interface().open_scene_from_path(path)
	status.text = "Map loaded. Select models and lights in the Scene tree. Add nodes and edit materials with Godot's usual tools."

func scene_opened(node: Node) -> void:
	if not node is Node3D: return
	var manifest_path := ModExport.manifest_for_scene(node.scene_file_path)
	if not manifest_path.is_empty(): picker.select(manifest_path.get_base_dir(), false)
	if node.has_node("_MapSession") or node.has_node("_ModelSession"): return
	if node.has_meta("mgs_model_reference"):
		var session := asset_authoring.attach_model(node, catalog, asset_root)
		if session != null: sessions.append(session)
		if not asset_authoring.error.is_empty(): status.text = asset_authoring.error
		return
	var data := manifest()
	for stage in data.get("stages", {}):
		if workspace.root.path_join(data.stages[stage].scene) != node.scene_file_path: continue
		var migrated: bool = node.get_meta("mgs_stage", "") != stage
		node.set_meta("mgs_stage", stage)
		for child in node.get_children():
			if child.get_meta("mgs_editor_preview", false):
				migrated = migrated or child.owner != null
				child.free()
		if migrated: get_editor_interface().mark_scene_as_unsaved()
	if not node.has_meta("mgs_stage"): return
	var coordinate_error := Coordinates.validate(node)
	if not coordinate_error.is_empty():
		status.text = coordinate_error
		return
	if Coordinates.migrate_to_editor(node): get_editor_interface().mark_scene_as_unsaved()
	if EventLightTemplates.attach(node): get_editor_interface().mark_scene_as_unsaved()
	var layout: Dictionary = prepared.get("maps", {}).get(str(node.get_meta("mgs_stage")), {})
	var light_error := MapLights.validate(layout, node.get_meta("mgs_light_overrides", {}))
	if not light_error.is_empty():
		status.text = light_error
		return
	var loader := DiscMap.new()
	var reference := loader.load_map(asset_root, prepared, str(node.get_meta("mgs_stage")), manifest_path)
	if reference == null:
		status.text = loader.error
		return
	map_authoring.attach_reference(node, reference, layout)
	sessions.append(node.get_node("_MapSession"))

func _apply_changes() -> void:
	sessions = sessions.filter(is_instance_valid)
	for session in sessions:
		if session.saving: session.prepare_save()

func scene_written(path: String) -> void:
	for session in sessions:
		if is_instance_valid(session) and session.overlay.scene_file_path == path:
			session.finish_save()

func export_mod() -> void:
	get_editor_interface().save_all_scenes()
	var default_path := ProjectSettings.globalize_path("res://../../../build/mod-exports/" + workspace.root.get_file() + ".zip")
	var source_file: String = workspace.root.path_join(".editor-source.json")
	if FileAccess.file_exists(source_file):
		var source = JSON.parse_string(FileAccess.get_file_as_string(source_file))
		if source is Dictionary and source.get("zip") is String: default_path = source.zip
	export_dialog.current_path = get_editor_interface().get_editor_settings().get_project_metadata("mgs_visuals", "export:" + workspace.root, default_path)
	export_dialog.popup_centered_ratio(0.7)

func write_export(destination: String) -> void:
	var error := ModExport.new().export_mod(workspace.root.path_join("mod.json"), destination, true)
	if error.is_empty(): get_editor_interface().get_editor_settings().set_project_metadata("mgs_visuals", "export:" + workspace.root, destination)
	status.text = "Exported " + ProjectSettings.globalize_path(destination) if error.is_empty() else error

func _exit_tree() -> void:
	remove_control_from_docks(panel)
	panel.queue_free()
