extends SceneTree

func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 2:
		push_error("Resource conversion requires a request file and output directory")
		quit(1)
		return
	var paths = JSON.parse_string(FileAccess.get_file_as_string(arguments[0]))
	if not paths is Array:
		push_error("Invalid resource conversion request")
		quit(1)
		return
	for index in paths.size():
		var resource := ResourceLoader.load(paths[index], "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		if resource == null:
			push_error("Cannot read binary Godot resource: " + str(paths[index]))
			quit(1)
			return
		var extension := "tscn" if resource is PackedScene else "tres"
		var path := str(arguments[1]).path_join("%d.%s" % [index, extension])
		var result := ResourceSaver.save(resource, path)
		if result != OK:
			push_error("Cannot convert binary Godot resource: " + error_string(result))
			quit(1)
			return
	quit()
