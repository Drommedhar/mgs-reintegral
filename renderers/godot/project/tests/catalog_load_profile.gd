extends SceneTree

func _initialize() -> void:
	var started := Time.get_ticks_msec()
	var content := preload("res://content_catalog.gd").new()
	var error := content.load_root("res://../../../.local/godot-content")
	if not error.is_empty(): push_error(error)
	print("MGS_CATALOG_PROFILE ms=%d assets=%d error=%s" % [Time.get_ticks_msec() - started, content.assets.size(), error])
	quit(0 if error.is_empty() else 1)
