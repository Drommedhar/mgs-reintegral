@tool
extends EditorPlugin

func _enter_tree() -> void:
	run.call_deferred()

func find_sdk(node: Node) -> Node:
	if node.get_script() != null and node.get_script().resource_path == "res://addons/mgs_editor/plugin.gd": return node
	for child in node.get_children():
		var found := find_sdk(child)
		if found != null: return found
	return null

func run() -> void:
	var sdk := find_sdk(get_tree().root)
	if sdk == null:
		push_error("SDK plugin did not load")
		get_tree().quit(1)
		return
	var frames := 0
	var reports := {}
	var started := Time.get_ticks_msec()
	while sdk.catalog_loading:
		reports[sdk.status.text] = true
		frames += 1
		await get_tree().process_frame
	var success: bool = frames > 5 and reports.size() > 5 and sdk.catalog.size() > 40000
	print("MGS_EDITOR_LOADING ms=%d frames=%d reports=%d assets=%d" % [Time.get_ticks_msec() - started, frames, reports.size(), sdk.catalog.size()])
	print("MGS_STARTUP_EDITOR_TEST failures=%d" % (0 if success else 1))
	get_tree().quit(0 if success else 1)
