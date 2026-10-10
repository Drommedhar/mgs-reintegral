@tool
extends EditorPlugin

const ModelContract = preload("res://model_contract.gd")
const LOCAL_MOD = "res://mods/local"
var panel: VBoxContainer
var status: Label
var search: LineEdit
var assets: ItemList
var stages: OptionButton
var catalog: Dictionary = {}
var asset_root: String

func _enter_tree() -> void:
	panel = VBoxContainer.new()
	panel.name = "MGS Visuals"
	search = LineEdit.new()
	search.placeholder_text = "Filter stable asset IDs"
	search.text_changed.connect(populate)
	panel.add_child(search)
	assets = ItemList.new()
	assets.custom_minimum_size = Vector2(280, 280)
	assets.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(assets)
	button("Reload prepared catalog", load_catalog)
	button("Create / open model override", create_model)
	stages = OptionButton.new()
	stages.add_item("s00a — docks")
	stages.add_item("s01a — helipad")
	panel.add_child(stages)
	button("Open captured stage preview (F7)", open_preview)
	button("Create / open stage lighting", create_stage)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(status)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, panel)
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
	catalog = parsed.assets
	populate(search.text)
	status.text = "%d local assets. Overrides are saved under mods/local (excluded from Git)." % catalog.size()

func populate(filter: String) -> void:
	assets.clear()
	for identity in catalog:
		if catalog[identity].kind == "model" and filter.to_lower() in str(identity).to_lower():
			var index := assets.add_item(identity)
			assets.set_item_metadata(index, identity)

func manifest() -> Dictionary:
	var path := LOCAL_MOD.path_join("mod.json")
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary and parsed.get("schema") == 1:
			for field in ["replacements", "stages"]:
				if not parsed.get(field, {}) is Dictionary:
					status.text = "Invalid local manifest field: " + field
					return {}
				if not parsed.has(field): parsed[field] = {}
			return parsed
		status.text = "Invalid local mod.json; refusing to overwrite it."
		return {}
	return {"schema": 1, "id": "local.visuals", "priority": 100, "replacements": {}, "stages": {}}

func save_manifest(data: Dictionary) -> bool:
	var file := FileAccess.open(LOCAL_MOD.path_join("mod.json"), FileAccess.WRITE)
	if file == null:
		status.text = "Cannot write local mod manifest."
		return false
	file.store_string(JSON.stringify(data, "\t") + "\n")
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

func create_model() -> void:
	var selected := assets.get_selected_items()
	if selected.is_empty():
		status.text = "Select a model ID first."
		return
	var identity: String = assets.get_item_metadata(selected[0])
	var filename := "models/" + identity.replace("/", "_") + ".tscn"
	var path := LOCAL_MOD.path_join(filename)
	var data := manifest()
	if data.is_empty(): return
	if not FileAccess.file_exists(path):
		var node := ModelContract.load_model(asset_root.path_join(catalog[identity].path))
		if node == null:
			status.text = "Cannot import " + identity
			return
		node.set_meta("mgs_asset_id", identity)
		var saved := write_scene(node, path)
		node.free()
		if not saved: return
	data.replacements[identity] = {"path": filename, "lighting": "unlit"}
	if not save_manifest(data): return
	get_editor_interface().open_scene_from_path(path)
	status.text = "Edit mesh/materials; preserve bone rests and mesh_NNN slots. Runtime validates the rig. Enable this manifest with -Mods."

func create_stage() -> void:
	var stage := "s00a" if stages.selected == 0 else "s01a"
	var filename := "stages/" + stage + ".tscn"
	var path := LOCAL_MOD.path_join(filename)
	var data := manifest()
	if data.is_empty(): return
	if not FileAccess.file_exists(path):
		var root := Node3D.new()
		root.name = stage + "_visuals"
		root.set_meta("coordinates", "Original world (x,-y,-z)/1000; visual overrides do not change collision")
		var preview_path := "res://.generated/previews/" + stage + ".tscn"
		if FileAccess.file_exists(preview_path):
			var packed := load(preview_path) as PackedScene
			if packed != null:
				var preview := packed.instantiate()
				preview.name = "EditorPreview"
				preview.set_meta("mgs_editor_preview", true)
				root.add_child(preview)
				preview.owner = root
		var environment := WorldEnvironment.new()
		environment.name = "LightingAndFog"
		environment.environment = Environment.new()
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color(0.25, 0.3, 0.4)
		environment.environment.ambient_light_energy = 0.8
		environment.environment.volumetric_fog_enabled = true
		environment.environment.volumetric_fog_density = 0.015
		root.add_child(environment)
		environment.owner = root
		var light := OmniLight3D.new()
		light.name = "EditableLight"
		light.position = Vector3(-6, 3, 5) if stage == "s00a" else Vector3(-4, 4, -20)
		light.omni_range = 12
		light.light_energy = 3
		root.add_child(light)
		light.owner = root
		var saved := write_scene(root, path)
		root.free()
		if not saved: return
	data.stages[stage] = {"scene": filename, "original_lighting": false}
	if not save_manifest(data): return
	get_editor_interface().open_scene_from_path(path)
	status.text = "Stage lights/fog are optional. Enable mods/local/mod.json at launch. Original lighting remains default without the mod."

func open_preview() -> void:
	var stage := "s00a" if stages.selected == 0 else "s01a"
	var path := "res://.generated/previews/" + stage + ".tscn"
	if not FileAccess.file_exists(path):
		status.text = "Press F7 during gameplay in this stage to capture an editor reference."
		return
	get_editor_interface().open_scene_from_path(path)

func _exit_tree() -> void:
	remove_control_from_docks(panel)
	panel.queue_free()
