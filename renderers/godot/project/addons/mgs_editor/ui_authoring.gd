@tool
extends RefCounted

const Builder = preload("res://goggles_scene.gd")
const Assets = preload("res://original_ui_assets.gd")
const Session = preload("res://addons/mgs_editor/ui_session.gd")
var error := ""

func open_goggles(workspace: RefCounted, directory: String, catalog: Dictionary, disc: int) -> String:
	return open_ui(workspace, directory, catalog, disc, "goggles")

func open_ui(workspace: RefCounted, directory: String, catalog: Dictionary, disc: int, slot: String) -> String:
	error = ""
	if slot not in ["goggles", "bars", "subtitles", "radar", "inventory", "codec", "options", "save_load", "title", "display_settings"]:
		error = "Unknown UI slot: " + slot
		return ""
	var manifest: Dictionary = workspace.manifest()
	if manifest.is_empty():
		error = workspace.error
		return ""
	var entry: Dictionary = manifest.ui.get(slot, {})
	if not entry.is_empty():
		var existing := preload("res://mod_registry.gd").asset_path(workspace.root, entry.get("scene", ""))
		if existing.is_empty() or not FileAccess.file_exists(existing):
			error = "UI scene is missing or outside this mod"
			return ""
		return existing
	var target: String = workspace.root.path_join("ui/" + slot)
	if DirAccess.dir_exists_absolute(target):
		error = "Unregistered UI folder already exists: " + target
		return ""
	var resources := Assets.new()
	resources.configure(directory, catalog, disc)
	var builders := {"display_settings": preload("res://display_menu_scene.gd"), "goggles": Builder, "bars": preload("res://bars_scene.gd"), "subtitles": preload("res://subtitles_scene.gd"), "radar": preload("res://radar_scene.gd"), "inventory": preload("res://inventory_scene.gd"), "codec": preload("res://codec_scene.gd"), "options": preload("res://options_scene.gd"), "save_load": preload("res://save_scene.gd"), "title": preload("res://title_scene.gd")}
	var builder: RefCounted = builders[slot].new()
	var scene: Control = builder.create(resources)
	if scene == null:
		error = builder.error
		return ""
	var status := DirAccess.make_dir_recursive_absolute(target)
	var scripts: Array = {"display_settings": ["display_menu_ui.gd"], "title": ["title_ui.gd", "title_button.gd", "title_layout.gd", "title_art.gd", "options_art.gd", "subtitles_text.gd", "subtitles_font.gd"], "save_load": ["save_ui.gd"], "goggles": ["goggles_ui.gd", "original_ui_shape.gd"], "bars": ["bars_ui.gd", "status_bar.gd"], "subtitles": ["subtitles_ui.gd", "subtitles_text.gd", "subtitles_font.gd"], "radar": ["radar_ui.gd", "radar_art.gd", "radar_map_ui.gd", "radar_alert_ui.gd", "radar_countdown_ui.gd"], "options": ["options_ui.gd", "options_layout.gd", "options_art.gd", "options_button.gd", "subtitles_text.gd", "subtitles_font.gd"], "codec": ["codec_ui.gd", "codec_controls.gd", "codec_button.gd", "codec_portrait.gd", "subtitles_text.gd", "subtitles_font.gd"], "inventory": ["inventory_ui.gd", "inventory_controls.gd", "inventory_button.gd", "inventory_art.gd", "inventory_panel.gd", "inventory_magazine.gd", "subtitles_text.gd", "subtitles_font.gd"]}[slot]
	for file in scripts:
		if status == OK: status = DirAccess.copy_absolute("res://" + file, target.path_join(file))
	if status == OK:
		scene.set_script(load(target.path_join(scripts[0])))
		for node in scene.find_children("*", "Control", true, false):
			if slot in ["radar", "inventory", "codec", "options", "save_load", "title", "display_settings"] and node.get_script() != null:
				var properties := {}
				for property in node.get_property_list():
					if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.usage & PROPERTY_USAGE_STORAGE: properties[property.name] = node.get(property.name)
				var file: String = node.get_script().resource_path.get_file()
				node.set_script(load(target.path_join(file)))
				for property in properties: node.set(property, properties[property])
			if node.get_script() == Builder.Shape:
				var identity: String = node.source_id
				var index: int = node.shape_index
				node.set_script(load(target.path_join("original_ui_shape.gd")))
				node.source_id = identity
				node.shape_index = index
			elif node.get_script() == preload("res://subtitles_text.gd"):
				node.set_script(load(target.path_join("subtitles_text.gd")))
			elif node.get_script() == preload("res://status_bar.gd"):
				var kind: int = node.kind
				var origin: Vector2 = node.native_origin
				node.set_script(load(target.path_join("status_bar.gd")))
				node.kind = kind
				node.native_origin = origin
				node.use_native_colors = kind == 0
				node.use_native_name = kind == 0
		var packed := PackedScene.new()
		status = packed.pack(scene)
		if status == OK: status = ResourceSaver.save(packed, target.path_join(slot + ".tscn"))
	scene.free()
	if status != OK:
		error = "Cannot create UI: " + error_string(status)
		return ""
	manifest.ui[slot] = {"scene": "ui/%s/%s.tscn" % [slot, slot]}
	if not workspace.save(manifest):
		error = workspace.error
		return ""
	return target.path_join(slot + ".tscn")

func attach(scene: Control, directory: String, catalog: Dictionary, disc: int) -> Node:
	var resources := Assets.new()
	resources.configure(directory, catalog, disc)
	var session := Session.new()
	session.name = "_UiSession"
	scene.add_child(session)
	error = session.initialize(scene, resources)
	return session
