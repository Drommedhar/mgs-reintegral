@tool
extends Node

var failures := 0

func _ready() -> void:
	if Engine.is_editor_hint() and OS.get_environment("MGS_EDITOR_DOCK_TEST") == "1": run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func settle() -> void:
	for frame in 5: await get_tree().process_frame

func snapshot(dock: Control, filename: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var image := dock.get_viewport().get_texture().get_image()
	var path := "res://.generated/editor-dock"
	DirAccess.make_dir_recursive_absolute(path)
	image.get_region(Rect2i(dock.get_global_rect())).save_png(path.path_join(filename))

func run() -> void:
	await settle()
	var plugins := get_tree().root.find_children("*", "EditorPlugin", true, false)
	var plugin: EditorPlugin
	for candidate in plugins:
		if candidate.get_script() != null and candidate.get_script().resource_path == "res://addons/mgs_editor/plugin.gd": plugin = candidate
	check(plugin != null, "MGS editor plugin did not load")
	if plugin == null:
		get_tree().quit(1)
		return
	while plugin.catalog_loading: await get_tree().process_frame
	var dock: Control = plugin.dock
	var ancestor: Node = dock
	while ancestor.get_parent() != null:
		if ancestor.get_parent() is TabContainer:
			ancestor.get_parent().current_tab = ancestor.get_parent().get_tab_idx_from_control(ancestor)
		ancestor = ancestor.get_parent()
	await settle()
	check(not dock is ScrollContainer, "Dock is still one giant scrolling panel")
	check(dock.tabs.get_tab_count() == 5 and dock.tabs.current_tab == 0, "Focused tabs missing or Maps is not the default")
	check(plugin.stages.list.size.y > 300, "Map list does not receive usable dock height: " + str(plugin.stages.list.size))
	check(plugin.stages.list.size.y > dock.size.y * 0.5, "Non-map controls consume most of the dock")
	check(plugin.stages.list.get_root().get_child_count() > 20, "Location list did not load")
	await snapshot(dock, "maps.png")
	plugin.stages.search.text = "Loading Dock"
	plugin.stages.populate()
	await settle()
	check(plugin.stages.list.get_root().get_child_count() == 1, "Dock variants do not share a location")
	await snapshot(dock, "variants.png")
	dock.tabs.current_tab = 2
	await settle()
	check(plugin.ui_browser.list.size.y > 300, "UI browser does not fill the tab")
	check(plugin.ui_browser.list.get_root().get_child_count() == 3, "UI entries are not grouped")
	var entry: TreeItem = plugin.ui_browser.list.get_root().get_child(0).get_child(0)
	entry.select(0)
	check(plugin.ui_browser.selected().id == "bars" and not plugin.ui_browser.open_button.disabled, "UI selection cannot be opened")
	plugin.ui_browser.set_manifest({"ui":{"bars":{"scene":"test.tscn"}}})
	check(plugin.ui_browser.list.get_selected().get_text(1) == "Edited", "UI edits are not shown in their browser")
	plugin.ui_browser.set_manifest(plugin.workspace.manifest())
	await snapshot(dock, "ui.png")
	dock.tabs.current_tab = 3
	await settle()
	check(plugin.effects_browser.list.get_root().get_child_count() == 2, "Effects not grouped by materials/post processing")
	await snapshot(dock, "effects.png")
	dock.tabs.current_tab = 4
	await settle()
	check(plugin.workspace_actions.is_visible_in_tree() and not plugin.stages.is_visible_in_tree(), "Workspace controls leak into Maps")
	await snapshot(dock, "mod.png")
	plugin.stages.search.text = ""
	plugin.stages.populate()
	dock.tabs.current_tab = 0
	print("MGS_EDITOR_DOCK_TEST map_height=%d dock_height=%d failures=%d" % [plugin.stages.list.size.y, dock.size.y, failures])
	get_tree().quit(1 if failures else 0)
