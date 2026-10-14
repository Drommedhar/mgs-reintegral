extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func sources(directory: String, paths: PackedStringArray) -> void:
	for file in DirAccess.get_files_at(directory):
		if file.get_extension().to_lower() in ["glb", "gltf", "tscn", "tres"]: paths.append(directory.path_join(file))
	for folder in DirAccess.get_directories_at(directory):
		if not folder.begins_with("."): sources(directory.path_join(folder), paths)

func run() -> void:
	var paths := PackedStringArray()
	if DirAccess.dir_exists_absolute("res://mods"): sources("res://mods", paths)
	var scanner := preload("res://material_texture_import.gd").new()
	for index in paths.size():
		print("MGS_LOAD_PROGRESS Checking material textures: %d / %d" % [index + 1, paths.size()])
		var resource := ResourceLoader.load(paths[index], "", ResourceLoader.CACHE_MODE_IGNORE)
		if resource == null:
			push_error("Cannot inspect material textures: " + paths[index])
			quit(1)
			return
		scanner.inspect(resource)
		await process_frame
	var changed: PackedStringArray = scanner.configure()
	if not scanner.error.is_empty():
		push_error(scanner.error)
		quit(1)
		return
	var receipt := FileAccess.open("res://.material-textures-changed", FileAccess.WRITE)
	if receipt == null:
		push_error("Cannot write material preparation receipt")
		quit(1)
		return
	receipt.store_string(JSON.stringify(Array(changed)))
	print("MGS_LOAD_PROGRESS Material filtering prepared: %d textures" % changed.size())
	quit()
