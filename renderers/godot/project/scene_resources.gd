extends RefCounted

var retained: Array[Resource] = []
var requested: Dictionary = {}

func finish_loading() -> void:
	for path in requested:
		ResourceLoader.load_threaded_get(path)
	requested.clear()
	retained.clear()

func prefetch(paths: Array[String]) -> String:
	for path in paths:
		if requested.has(path) or ResourceLoader.has_cached(path): continue
		if not ResourceLoader.exists(path, "PackedScene"): return "Mod scene is missing: " + path
		var error := ResourceLoader.load_threaded_request(path, "PackedScene")
		if error != OK: return "Cannot load mod scene %s: %s" % [path, error_string(error)]
		requested[path] = true
	return ""

func prepare(paths: Array[String], tree: SceneTree, progress: Callable) -> String:
	var error := prefetch(paths)
	if not error.is_empty(): return error
	var next: Array[Resource] = []
	for index in paths.size():
		var path := paths[index]
		if not ResourceLoader.exists(path, "PackedScene"): return "Mod scene is missing: " + path
		if not requested.has(path) and ResourceLoader.has_cached(path):
			next.append(load(path))
			continue
		progress.call("Loading mod scene %d / %d: %s" % [index + 1, paths.size(), path.get_file()], 0.0)
		await tree.process_frame
		var previous := -1
		while true:
			var amount := []
			var state := ResourceLoader.load_threaded_get_status(path, amount)
			if state == ResourceLoader.THREAD_LOAD_FAILED or state == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				if state == ResourceLoader.THREAD_LOAD_FAILED: ResourceLoader.load_threaded_get(path)
				requested.erase(path)
				return "Cannot load mod scene: " + path
			var percent := int(float(amount[0]) * 100.0) if not amount.is_empty() else 0
			if percent != previous:
				previous = percent
				progress.call("Loading mod scene %d / %d: %s" % [index + 1, paths.size(), path.get_file()], float(percent))
			if state == ResourceLoader.THREAD_LOAD_LOADED: break
			await tree.process_frame
		var resource := ResourceLoader.load_threaded_get(path) as PackedScene
		requested.erase(path)
		if resource == null: return "Mod scene is not a PackedScene: " + path
		next.append(resource)
	retained = next
	return ""
