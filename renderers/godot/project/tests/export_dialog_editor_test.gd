@tool
extends EditorPlugin

var failures := 0
var export_complete := false

func check(value: bool, message: String) -> void:
	if value: return
	failures += 1
	push_error(message)

func snapshot(dialog: Window, label: String) -> void:
	for frame in 5: await get_tree().process_frame
	RenderingServer.force_draw(false)
	var image := dialog.get_texture().get_image()
	check(image != null and not image.is_empty(), label + ": export window has no rendered image")
	if image == null or image.is_empty(): return
	var folder := ProjectSettings.globalize_path("res://../../../dialog-captures")
	DirAccess.make_dir_recursive_absolute(folder)
	check(image.save_png(folder.path_join(label + ".png")) == OK, "Cannot capture export dialog")
	for control in [dialog.detail, dialog.bar, dialog.elapsed, dialog.cancel_button]:
		var rect := Rect2i(control.get_global_rect())
		var colors := {}
		for y in range(maxi(rect.position.y, 0), mini(rect.end.y, image.get_height())):
			for x in range(maxi(rect.position.x, 0), mini(rect.end.x, image.get_width())):
				colors[image.get_pixel(x, y).to_rgba32()] = true
		print("MGS_EXPORT_DIALOG_PIXELS %s %s visible=%s rect=%s colors=%d" % [label, control.get_class(), control.is_visible_in_tree(), rect, colors.size()])
		check(colors.size() > 8, label + ": export control did not render: " + control.get_class())

func export_zip(panel: Node, destination: String) -> void:
	await panel.write_export(destination, true)
	export_complete = true

func actual_export(plugin: EditorPlugin) -> void:
	plugin.workspace.root = "res://mods/dialog.test"
	check(plugin.workspace.save({"schema":1, "id":"dialog.test", "resources":{"payload":{"path":"payload.bin"}}}), plugin.workspace.error)
	var block := PackedByteArray()
	block.resize(1024 * 1024)
	block.fill(65)
	var file := FileAccess.open(plugin.workspace.root.path_join("payload.bin"), FileAccess.WRITE)
	for index in 128: file.store_buffer(block)
	file.close()
	var panel: Node = plugin.workspace_actions
	panel.activate()
	var destination := ProjectSettings.globalize_path("res://../../../dialog-export.zip")
	export_zip(panel, destination)
	var captured := {}
	var deadline := Time.get_ticks_msec() + 60000
	while not export_complete and Time.get_ticks_msec() < deadline:
		var phase: String = panel.export_progress.phase
		var measurable: bool = phase != "compressing" or (panel.export_progress.bar.value > 0 and panel.export_progress.bar.value < 100)
		if phase in ["catalogs", "compressing"] and measurable and not captured.has(phase):
			await snapshot(panel.export_progress, "export-" + phase)
			captured[phase] = true
		await get_tree().process_frame
	check(export_complete and FileAccess.file_exists(destination), "Native dialog export did not complete")
	check(captured.has("catalogs") and captured.has("compressing"), "Native dialog did not render both export phases")
	check(not panel.export_progress.visible, "Completed export left the modal window open")

func run() -> void:
	while EditorInterface.get_resource_filesystem().is_scanning(): await get_tree().process_frame
	var plugin: EditorPlugin
	for candidate in get_tree().root.find_children("*", "EditorPlugin", true, false):
		if candidate.get_script() != null and candidate.get_script().resource_path == "res://addons/mgs_editor/plugin.gd": plugin = candidate
	check(plugin != null, "MGS editor plugin did not load")
	if plugin == null:
		get_tree().quit(1)
		return
	while plugin.catalog_loading: await get_tree().process_frame
	var ancestor: Node = plugin.workspace_actions
	while ancestor.get_parent() != null:
		if ancestor.get_parent() is TabContainer:
			ancestor.get_parent().current_tab = ancestor.get_parent().get_tab_idx_from_control(ancestor)
		ancestor = ancestor.get_parent()
	var dialog: Window = plugin.workspace_actions.export_progress
	check(not get_tree().root.gui_embed_subwindows, "Fixture must exercise a native editor window")
	dialog.begin()
	dialog.show_status({"phase":"catalogs", "detail":"Validating prepared content…", "can_cancel":true})
	await snapshot(dialog, "validating")
	dialog.show_status({"phase":"compressing", "detail":"Writing textures/payload.bin", "total":100, "completed":42, "can_cancel":true})
	await snapshot(dialog, "compressing")
	dialog.finish()
	dialog.begin()
	dialog.show_status({"phase":"catalogs", "detail":"Validating prepared content…", "can_cancel":true})
	await snapshot(dialog, "reopened")
	dialog.cancel_button.pressed.emit()
	check(dialog.cancelling, "Visible Cancel button did not request cancellation")
	dialog.finish()
	await actual_export(plugin)
	print("MGS_EXPORT_DIALOG_EDITOR_TEST failures=%d" % failures)
	get_tree().quit(1 if failures else 0)

func _enter_tree() -> void:
	run.call_deferred()
