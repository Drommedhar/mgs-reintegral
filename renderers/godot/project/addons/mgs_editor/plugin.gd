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
const WorkspaceActions = preload("res://addons/mgs_editor/workspace_actions.gd")
const AssetAuthoring = preload("res://addons/mgs_editor/asset_authoring.gd")
const ContentCatalog = preload("res://content_catalog.gd")
const Registry = preload("res://mod_registry.gd")
const NativeAuthoring = preload("res://addons/mgs_editor/native_authoring.gd")
const SceneCatalog = preload("res://addons/mgs_editor/scene_catalog.gd")
const NativeTestSession = preload("res://addons/mgs_editor/native_test_session.gd")
const DockLayout = preload("res://addons/mgs_editor/dock_layout.gd")
const ResourceBrowser = preload("res://addons/mgs_editor/resource_browser.gd")
const EditorResources = preload("res://addons/mgs_editor/editor_resources.gd")
const SceneBrowser = preload("res://addons/mgs_editor/scene_browser.gd")
const Cinematics = preload("res://cinematic_catalog.gd")
const CinematicPreview = preload("res://cinematic_source.gd")
var map_authoring := MapAuthoring.new()
var workspace := ModWorkspace.new()
var asset_authoring := AssetAuthoring.new()
var effect_authoring := preload("res://addons/mgs_editor/effect_authoring.gd").new()
var appearance_authoring := preload("res://addons/mgs_editor/appearance_authoring.gd").new()
var picker: HBoxContainer
var asset_dialog := EditorFileDialog.new()
var workspace_actions := WorkspaceActions.new()
var pending_asset := ""
var dock: VBoxContainer
var status: Label
var search: LineEdit
var assets: ItemList
var stages: VBoxContainer
var asset_kind := OptionButton.new()
var ui_browser := ResourceBrowser.new()
var effects_browser := ResourceBrowser.new()
var mod_resources_editor := preload("res://addons/mgs_editor/mod_resources_editor.gd").new()
var mod_profile_editor := preload("res://addons/mgs_editor/mod_profile_editor.gd").new()
var content := ContentCatalog.new()
var profiles: OptionButton
var run_button: Button
var stop_button: Button
var native_test := NativeTestSession.new()
var test_status: Label
var catalog: Dictionary = {}
var prepared: Dictionary = {}
var asset_root: String
var sessions: Array[Node] = []
var pending_previews: Dictionary = {}
var catalog_loading := false
var closing := false

func _enter_tree() -> void:
	dock = DockLayout.new()
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.max_lines_visible = 3
	status.mouse_entered.connect(func(): status.tooltip_text = status.text)
	picker = WorkspacePicker.new()
	picker.selected.connect(select_workspace)
	picker.failed.connect(func(message): status.text = message)
	dock.add_child(picker)
	dock.move_child(picker, 0)
	build_maps()
	build_assets()
	build_resources()
	var mod_tabs := DockLayout.sub_tabs(dock.page("Mod"))
	var mod_page: VBoxContainer = dock.page("Workspace", mod_tabs)
	dock.page("Enabled mods", mod_tabs).add_child(mod_profile_editor)
	mod_profile_editor.reported.connect(func(message): status.text = message)
	mod_profile_editor.changed.connect(profile_changed)
	DockLayout.note(mod_page, "Save & export")
	workspace_actions.workspace = workspace
	workspace_actions.selected.connect(func(path): picker.select(path, true))
	workspace_actions.reported.connect(func(message): status.text = message)
	mod_page.add_child(workspace_actions)
	DockLayout.note(mod_page, "Prepared content")
	DockLayout.button(mod_page, "Reload catalog", load_catalog)
	dock.add_child(status)
	dock.add_child(native_test)
	native_test.changed.connect(test_changed)
	refresh_profiles("")
	asset_dialog.access = FileDialog.ACCESS_FILESYSTEM
	asset_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	asset_dialog.file_selected.connect(assign_replacement)
	dock.add_child(asset_dialog)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)
	scene_changed.connect(scene_opened)
	scene_saved.connect(scene_written)
	var material_imports := preload("res://addons/mgs_editor/material_imports.gd").new()
	add_child(material_imports)
	material_imports.activate(self)
	get_editor_interface().get_selection().selection_changed.connect(select_original)
	load_catalog.call_deferred()
	workspace_actions.activate()

func build_maps() -> void:
	var map_page: VBoxContainer = dock.page("Maps")
	var tabs := DockLayout.sub_tabs(map_page)
	var browse: VBoxContainer = dock.page("Browse", tabs)
	stages = SceneBrowser.new()
	stages.activated.connect(create_stage)
	browse.add_child(stages)
	var test: VBoxContainer = dock.page("Test", tabs)
	DockLayout.note(test, "Preview or run the saved enabled profile from Mod → Enabled mods. Edit each mod in its source scene.")
	DockLayout.button(test, "Preview profile", preview_profile)
	profiles = OptionButton.new()
	profiles.fit_to_longest_item = false
	test.add_child(profiles)
	var controls := HBoxContainer.new()
	test.add_child(controls)
	run_button = DockLayout.button(controls, "Run", run_native_map)
	stop_button = DockLayout.button(controls, "Stop", native_test.stop)
	stop_button.disabled = true
	DockLayout.button(test, "Open test logs", open_test_logs)
	test_status = DockLayout.note(test, "Open a map to select a test profile.")

func build_assets() -> void:
	var asset_page: VBoxContainer = dock.page("Assets")
	var tabs := DockLayout.sub_tabs(asset_page)
	var page: VBoxContainer = dock.page("Original assets", tabs)
	var resources: VBoxContainer = dock.page("Mod resources", tabs)
	mod_resources_editor.workspace = workspace
	mod_resources_editor.reported.connect(func(message): status.text = message)
	mod_resources_editor.changed.connect(func(): workspace_actions.invalidate())
	mod_resources_editor.open_requested.connect(open_mod_resource)
	resources.add_child(mod_resources_editor)
	asset_kind.add_item("Models")
	asset_kind.add_item("Textures")
	asset_kind.add_item("All assets")
	asset_kind.item_selected.connect(func(_index): populate(search.text))
	page.add_child(asset_kind)
	search = LineEdit.new()
	search.placeholder_text = "Find by map name, model or texture ID"
	search.text_changed.connect(populate)
	page.add_child(search)
	assets = ItemList.new()
	assets.custom_minimum_size.y = 120
	assets.size_flags_vertical = Control.SIZE_EXPAND_FILL
	assets.item_activated.connect(func(_index): open_asset())
	page.add_child(assets)
	DockLayout.button(page, "Edit model / view texture", open_asset)
	DockLayout.button(page, "Assign replacement…", choose_replacement)
	var more := MenuButton.new()
	more.text = "Asset tools"
	var menu := more.get_popup()
	var actions := [show_model_textures, show_source, open_effect_material]
	for title in ["Show model textures", "Show original source file", "Edit texture's effect material"]: menu.add_item(title)
	menu.id_pressed.connect(func(id): actions[id].call())
	page.add_child(more)

func open_mod_resource(path: String) -> void:
	if path.get_extension().to_lower() in ["tscn", "scn"]:
		get_editor_interface().open_scene_from_path(path)
	elif ResourceLoader.exists(path):
		var resource := load(path)
		if resource == null: status.text = "Cannot open mod resource: " + path
		elif resource is Script: get_editor_interface().edit_script(resource)
		else: get_editor_interface().edit_resource(resource)
	else:
		get_editor_interface().get_file_system_dock().navigate_to_path(path)
		status.text = "Selected file in FileSystem: " + path

func build_resources() -> void:
	var ui_page: VBoxContainer = dock.page("UI")
	ui_browser.name = "UI"
	ui_browser.definitions = EditorResources.UI
	ui_browser.activated.connect(open_ui)
	ui_page.add_child(ui_browser)
	var effects_page: VBoxContainer = dock.page("Effects")
	effects_browser.name = "Effects"
	effects_browser.definitions = EditorResources.EFFECTS
	effects_browser.activated.connect(open_named_effect)
	effects_page.add_child(effects_browser)

func open_named_effect(identity: String) -> void:
	match identity:
		"camouflage": open_camouflage_material()
		"night_vision", "thermal_vision": open_vision(identity)
		"snow": edit_effect("mgs/effects/snow")

func refresh_mod_views(data: Dictionary) -> void:
	stages.set_manifest(data)
	ui_browser.set_manifest(data)
	effects_browser.set_manifest(data)
	mod_resources_editor.refresh()
	mod_profile_editor.set_active(workspace.root.path_join("mod.json"))

func load_catalog() -> void:
	if catalog_loading: return
	catalog_loading = true
	catalog.clear()
	prepared.clear()
	assets.clear()
	stages.configure({}, "", {})
	var error := await content.load_responsive("res://../../../.local/godot-content", get_tree(), func(message, _percent = -1.0): status.text = message)
	if closing: return
	catalog_loading = false
	if not error.is_empty():
		status.text = error
		return
	asset_root = content.root
	catalog = content.assets
	var sources := {}
	for disc in content.catalogs: sources[disc] = content.for_disc(disc)
	stages.configure(sources, asset_root, workspace.manifest())
	select_disc(int(content.catalogs.keys()[0]))
	refresh_mod_views(workspace.manifest())
	if content.unverified_assets > 0:
		status.text += "\nOlder catalog has unverified assets. Re-run preparation for revision checks."
	scene_opened(get_editor_interface().get_edited_scene_root())

func select_disc(disc: int) -> void:
	prepared = content.for_disc(disc)
	if prepared.is_empty():
		status.text = "Prepare original Disc %d content first." % disc
		return
	stages.preferred_disc = disc
	populate(search.text)
	status.text = "Prepared content loaded. Select a map to begin."

func populate(filter: String) -> void:
	assets.clear()
	for identity in catalog:
		if prepared.has("disc") and str(identity).get_slice("/", 2) != "disc%d" % prepared.disc: continue
		var kind: String = catalog[identity].get("kind", "")
		if kind not in ["model", "texture"]: continue
		if asset_kind.selected != 2 and kind != ("model" if asset_kind.selected == 0 else "texture"): continue
		var stage: String = str(identity).get_slice("/", 4)
		var location: String = SceneCatalog.descriptions.get(stage, {}).get("name", stage)
		if not filter.is_empty() and filter.to_lower() not in (str(identity) + " " + location).to_lower(): continue
		var index := assets.add_item(str(identity).get_file() + " · " + location + " · " + stage)
		assets.set_item_metadata(index, identity)
		assets.set_item_tooltip(index, identity)

func manifest() -> Dictionary:
	var data := workspace.manifest()
	if data.is_empty(): status.text = workspace.error
	return data

func save_manifest(data: Dictionary) -> bool:
	if not workspace.save(data):
		status.text = workspace.error
		return false
	refresh_mod_views(data)
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
	if identity == "mgs/effects/snow":
		open_effect_material()
		return
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
	refresh_mod_views(workspace.manifest())

func choose_replacement() -> void:
	pending_asset = selected_asset()
	if pending_asset.is_empty(): return
	if pending_asset == "mgs/effects/snow":
		open_effect_material()
		return
	asset_dialog.filters = PackedStringArray(["*.png,*.webp ; Texture replacement"]) if catalog[pending_asset].kind == "texture" else PackedStringArray(["*.glb,*.gltf,*.tscn ; Rigged model (GLB is copied; glTF/TSCN must be inside the mod)"])
	asset_dialog.current_dir = ProjectSettings.globalize_path(workspace.root)
	asset_dialog.popup_centered_ratio(0.7)

func show_source() -> void:
	var identity := selected_asset()
	if catalog.has(identity): OS.shell_show_in_file_manager(asset_root.path_join(catalog[identity].path))

func show_model_textures() -> void:
	var identity := selected_asset()
	if not catalog.has(identity) or catalog[identity].kind != "model": return
	var textures := asset_authoring.texture_ids(identity, catalog, asset_root)
	asset_kind.select(1)
	assets.clear()
	for texture in textures:
		var index := assets.add_item(texture)
		assets.set_item_metadata(index, texture)
	status.text = "%d textures used by %s. Select one to view or replace it." % [textures.size(), identity.get_file()]

func open_effect_material() -> void:
	var identity := selected_asset()
	if not identity.is_empty(): edit_effect(identity)

func edit_effect(identity: String) -> void:
	if identity != "mgs/effects/snow" and catalog.get(identity, {}).get("kind") != "texture":
		status.text = "Select snow or an original texture used by a world effect."
		return
	var material := effect_authoring.open_material(workspace, identity)
	if material == null:
		status.text = effect_authoring.error
		return
	get_editor_interface().get_resource_filesystem().scan()
	get_editor_interface().edit_resource(material)
	refresh_mod_views(workspace.manifest())
	status.text = "Edit Shader Parameters > Appearance, then save the material. Custom textures must be inside this mod. Native run reloads saved changes. Target: " + identity

func open_camouflage_material() -> void:
	var material := appearance_authoring.open_material(workspace)
	if material == null:
		status.text = appearance_authoring.error
		return
	get_editor_interface().get_resource_filesystem().scan()
	get_editor_interface().edit_resource(material)
	refresh_mod_views(workspace.manifest())
	status.text = "Edit Shader Parameters > Appearance and save. Native camouflage controls activation and transitions for Snake and scripted actors."

func open_vision(kind: String) -> void:
	var authoring := preload("res://addons/mgs_editor/night_vision_authoring.gd").new()
	var effect := authoring.open_effect(workspace, kind)
	if effect == null:
		status.text = authoring.error
		return
	get_editor_interface().get_resource_filesystem().scan()
	get_editor_interface().edit_resource(effect)
	refresh_mod_views(workspace.manifest())
	status.text = "Edit Vision, Display and Heat settings in the Inspector, then save. Equip the corresponding goggles in a native test run to preview."

func open_ui(slot: String) -> void:
	var authoring := preload("res://addons/mgs_editor/ui_authoring.gd").new()
	var path := authoring.open_ui(workspace, asset_root, catalog, int(prepared.get("disc", 1)), slot)
	if path.is_empty():
		status.text = authoring.error
		return
	get_editor_interface().get_resource_filesystem().scan()
	get_editor_interface().open_scene_from_path(path)
	refresh_mod_views(workspace.manifest())
	status.text = "Edit the UI Controls and their fonts, colors or scripts, then save. Export includes the UI edits and references to your local original artwork."

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
	refresh_mod_views(workspace.manifest())

func select_original() -> void:
	var selected := get_editor_interface().get_selection().get_selected_nodes()
	if selected.size() != 1: return
	var node: Node = selected[0]
	while node != null:
		var identity: String = node.get_meta("mgs_asset_id", node.get_meta("mgs_model_reference", ""))
		if catalog.has(identity):
			asset_kind.select(0 if catalog[identity].kind == "model" else 1)
			search.text = identity
			populate(identity)
			assets.select(0)
			return
		node = node.get_parent()

func select_workspace(path: String, open_scene: bool) -> void:
	workspace.root = path
	workspace_actions.activate()
	var data := manifest()
	if data.is_empty(): return
	refresh_mod_views(data)
	status.text = "Active mod: " + path
	if not open_scene: return
	var scenes: Array = data.get("stages", {}).values()
	if scenes.is_empty(): scenes = data.get("ui", {}).values()
	if not scenes.is_empty(): get_editor_interface().open_scene_from_path(path.path_join(scenes[0].scene))

func create_stage() -> void:
	var selected: Dictionary = stages.selected()
	if selected.is_empty():
		status.text = "No prepared map is available. Prepare the original content first."
		return
	select_disc(int(selected.source.disc))
	var stage: String = selected.stage
	var clip: String = selected.get("clip", "")
	var unavailable := SceneCatalog.availability(prepared, asset_root, stage, clip)
	if not unavailable.is_empty():
		status.text = unavailable
		return
	var target := Registry.stage_target(stage, int(prepared.disc))
	var filename := "stages/" + target + ".tscn"
	var data := manifest()
	if data.is_empty(): return
	if prepared.disc == 1 and not data.stages.has(target) and data.stages.has(stage): target = stage
	filename = data.stages.get(target, {}).get("scene", filename)
	var path := workspace.root.path_join(filename)
	var original_lighting := false
	if not FileAccess.file_exists(path):
		var mods := Registry.new()
		var manifest_path := workspace.root.path_join("mod.json")
		var error := mods.configure(catalog, [manifest_path] if FileAccess.file_exists(manifest_path) else [])
		if not error.is_empty():
			status.text = error
			return
		original_lighting = mods.stage_definition(stage, int(prepared.disc)).get("original_lighting", false)
		var root := map_authoring.create_map(mods, content, stage, int(prepared.disc), clip)
		if root == null:
			status.text = map_authoring.error
			return
		var saved := write_scene(root, path)
		root.free()
		if not saved: return
	if not data.stages.has(target): data.stages[target] = {"scene": filename, "original_lighting": original_lighting}
	if not save_manifest(data): return
	pending_previews[path] = clip
	status.text = "Opening map…"
	get_editor_interface().open_scene_from_path(path)
	if pending_previews.has(path): scene_opened(get_editor_interface().get_edited_scene_root())

func select_preview(node: Node3D) -> String:
	if not pending_previews.has(node.scene_file_path): return ""
	var clip: String = pending_previews[node.scene_file_path]
	pending_previews.erase(node.scene_file_path)
	var stage: String = node.get_meta("mgs_stage", "")
	var mismatch := SceneCatalog.source_error(node.get_meta("mgs_scene_source", {}), prepared, stage)
	if not mismatch.is_empty(): return mismatch
	if node.get_meta("mgs_preview_clip", "") == clip: return ""
	if node.has_node("_MapSession"):
		node.get_node("_MapSession").detach_for_reload()
		node.get_node("_MapSession").free()
	node.set_meta("mgs_preview_clip", clip)
	node.set_meta("mgs_scene_source", SceneCatalog.source(prepared, stage, clip))
	get_editor_interface().mark_scene_as_unsaved()
	return ""

func scene_opened(node: Node) -> void:
	if catalog_loading or catalog.is_empty(): return
	if node is Node3D and node.get_meta("mgs_profile_preview", false):
		var owner_workspace: String = node.get_meta("mgs_profile_workspace", "")
		if not owner_workspace.is_empty(): picker.select(owner_workspace, false)
		refresh_profiles(str(node.get_meta("mgs_stage")))
		load_profile_preview(node)
		return
	refresh_profiles(str(node.get_meta("mgs_stage", "")) if node != null else "")
	if node is Control and node.get_meta("mgs_ui_slot", "") in ["goggles", "bars", "subtitles", "radar", "inventory", "codec", "options", "save_load", "title", "display_settings"]:
		var manifest_path := ModExport.manifest_for_scene(node.scene_file_path)
		if not manifest_path.is_empty(): picker.select(manifest_path.get_base_dir(), false)
		if not node.has_node("_UiSession"):
			var authoring := preload("res://addons/mgs_editor/ui_authoring.gd").new()
			sessions.append(authoring.attach(node, asset_root, catalog, int(prepared.get("disc", 1))))
			if not authoring.error.is_empty(): status.text = authoring.error
		return
	if not node is Node3D: return
	var source_disc := int(node.get_meta("mgs_scene_source", {}).get("disc", 0))
	if node.has_meta("mgs_model_reference"):
		source_disc = str(node.get_meta("mgs_model_reference")).get_slice("/", 2).trim_prefix("disc").to_int()
	if source_disc in [1, 2] and prepared.get("disc") != source_disc: select_disc(source_disc)
	var manifest_path := ModExport.manifest_for_scene(node.scene_file_path)
	if not manifest_path.is_empty(): picker.select(manifest_path.get_base_dir(), false)
	var preview_error := select_preview(node)
	if not preview_error.is_empty():
		status.text = preview_error
		return
	if node.has_node("_MapSession") or node.has_node("_ModelSession"): return
	if node.has_meta("mgs_model_reference"):
		var session := asset_authoring.attach_model(node, catalog, asset_root)
		if session != null: sessions.append(session)
		if not asset_authoring.error.is_empty(): status.text = asset_authoring.error
		return
	var data := manifest()
	for target in data.get("stages", {}):
		if workspace.root.path_join(data.stages[target].scene) != node.scene_file_path: continue
		var stage := Registry.target_stage(target)
		var migrated: bool = node.get_meta("mgs_stage", "") != stage
		node.set_meta("mgs_stage", stage)
		for child in node.get_children():
			if child.get_meta("mgs_editor_preview", false):
				migrated = migrated or child.owner != null
				child.free()
		if migrated: get_editor_interface().mark_scene_as_unsaved()
	if not node.has_meta("mgs_stage"): return
	refresh_profiles(str(node.get_meta("mgs_stage")))
	var source_error := SceneCatalog.source_error(node.get_meta("mgs_scene_source", {}), prepared, str(node.get_meta("mgs_stage")))
	if not source_error.is_empty():
		status.text = source_error
		return
	var coordinate_error := Coordinates.validate(node)
	if not coordinate_error.is_empty():
		status.text = coordinate_error
		return
	if Coordinates.migrate_to_editor(node): get_editor_interface().mark_scene_as_unsaved()
	if EventLightTemplates.attach(node): get_editor_interface().mark_scene_as_unsaved()
	var clip: String = node.get_meta("mgs_preview_clip", "")
	var layout := Cinematics.layout(prepared, str(node.get_meta("mgs_stage")), clip)
	var light_error := MapLights.validate(layout, node.get_meta("mgs_light_overrides", {}))
	if not light_error.is_empty():
		status.text = light_error
		return
	var loader := DiscMap.new()
	var reference := loader.load_map(asset_root, prepared, str(node.get_meta("mgs_stage")), manifest_path, clip)
	if reference == null:
		status.text = loader.error
		return
	if not clip.is_empty():
		var camera_error := CinematicPreview.attach(reference, asset_root, prepared, clip)
		if not camera_error.is_empty():
			reference.free()
			status.text = camera_error
			return
	map_authoring.attach_reference(node, reference, layout)
	var session := node.get_node("_MapSession")
	sessions.append(session)
	if not clip.is_empty():
		var camera_error: String = session.attach_camera(reference, Cinematics.source(prepared, clip))
		if not camera_error.is_empty():
			status.text = camera_error
			return
	var authoring := NativeAuthoring.new()
	if authoring.attach_declarations(node, reference, session, manifest_path.get_base_dir()): get_editor_interface().mark_scene_as_unsaved()
	if not authoring.error.is_empty():
		status.text = authoring.error
		return
	authoring.attach_previews(node, catalog, asset_root, session)
	status.text = "Map loaded. Edit models and lights in the Scene tree."
	if not clip.is_empty(): status.text += " Edit OriginalCameraTimeline keys for this clip. Only changed keys are exported; scenery edits apply to this stage."
	if not authoring.error.is_empty(): status.text = authoring.error

func run_native_map() -> void:
	var root := get_editor_interface().get_edited_scene_root()
	if root == null:
		status.text = "Open a mod scene before testing the workspace."
		return
	get_editor_interface().save_all_scenes()
	var manifest_path := ModExport.manifest_for_scene(root.scene_file_path)
	if root.get_meta("mgs_profile_preview", false): manifest_path = workspace.root.path_join("mod.json")
	if manifest_path.is_empty():
		status.text = "Save this map inside a mod workspace before testing."
		return
	var disc := int(root.get_meta("mgs_scene_source", {}).get("disc", prepared.get("disc", 1)))
	var validation := Registry.new().configure(catalog, mod_profile_editor.profile.paths(), mod_profile_editor.profile.priorities())
	if not validation.is_empty():
		test_status.text = validation
		return
	var error := native_test.start(profiles.get_item_metadata(profiles.selected), manifest_path, disc, mod_profile_editor.profile)
	if not error.is_empty(): test_status.text = error

func preview_profile() -> void:
	var source := get_editor_interface().get_edited_scene_root()
	if not source is Node3D or not source.has_meta("mgs_stage"):
		status.text = "Open a map before previewing the enabled profile."
		return
	get_editor_interface().save_all_scenes()
	if source.get_meta("mgs_profile_preview", false):
		load_profile_preview(source)
		return
	var preview := Node3D.new()
	preview.name = "EnabledProfilePreview"
	preview.set_meta("mgs_profile_preview", true)
	preview.set_meta("mgs_profile_workspace", workspace.root)
	for key in ["mgs_stage", "mgs_scene_source", "mgs_preview_clip"]:
		preview.set_meta(key, source.get_meta(key, "" if key != "mgs_scene_source" else {}))
	var identity := source.scene_file_path + "/" + str(source.get_meta("mgs_preview_clip", ""))
	var path := "res://.godot/mgs_profile_previews/%s-%s.tscn" % [source.get_meta("mgs_stage"), identity.sha256_text().left(12)]
	var saved := write_scene(preview, path)
	preview.free()
	if saved: get_editor_interface().open_scene_from_path(path)

func load_profile_preview(root: Node3D) -> void:
	for child in root.get_children(): child.free()
	var preview := preload("res://addons/mgs_editor/profile_preview.gd").new()
	var disc := int(root.get_meta("mgs_scene_source", {}).get("disc", prepared.get("disc", 1)))
	var map := preview.create(content, mod_profile_editor.profile, str(root.get_meta("mgs_stage")), disc, str(root.get_meta("mgs_preview_clip", "")))
	if map == null:
		status.text = preview.error
		mod_profile_editor.show_diagnostics(PackedStringArray([preview.error]))
		return
	map.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(map)
	mod_profile_editor.show_diagnostics(preview.diagnostics)
	status.text = "Enabled profile preview. Edit each mod's source scene, then Preview profile again to load saved changes."

func profile_changed() -> void:
	var root := get_editor_interface().get_edited_scene_root()
	if root is Node3D and root.get_meta("mgs_profile_preview", false): load_profile_preview(root)
	else: status.text = "Enabled profile updated. Preview profile or Run to use it."

func refresh_profiles(stage: String) -> void:
	profiles.clear()
	for profile in SceneCatalog.launch_profiles(stage):
		var index := profiles.item_count
		profiles.add_item(profile.label)
		profiles.set_item_metadata(index, profile.stage)
		profiles.set_item_tooltip(index, profile.detail)
	profiles.select(0)

func test_changed(message: String, active: bool) -> void:
	test_status.text = message
	run_button.disabled = active
	stop_button.disabled = not active
	profiles.disabled = active

func open_test_logs() -> void:
	if native_test.directory.is_empty():
		test_status.text = "No native test has been started in this editor session."
		return
	OS.shell_open(native_test.directory)

func _apply_changes() -> void:
	sessions = sessions.filter(is_instance_valid)
	for session in sessions:
		if session.saving: session.prepare_save()

func scene_written(path: String) -> void:
	for session in sessions:
		if is_instance_valid(session) and session.overlay.scene_file_path == path:
			session.finish_save()
	refresh_mod_views(workspace.manifest())
	workspace_actions.invalidate()

func _exit_tree() -> void:
	closing = true
	content.finish_loading()
	native_test.changed.disconnect(test_changed)
	native_test.stop()
	remove_control_from_docks(dock)
	dock.queue_free()
