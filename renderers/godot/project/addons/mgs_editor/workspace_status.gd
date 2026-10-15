@tool
extends RefCounted

const State = preload("res://addons/mgs_editor/workspace_state.gd")
const Prepared = preload("res://prepared_catalog.gd")
var worker := Thread.new()
var mutex := Mutex.new()
var cancelled := false

func start(root: String) -> Error:
	mutex.lock()
	cancelled = false
	mutex.unlock()
	return worker.start(inspect.bind(root))

func cancel() -> void:
	mutex.lock()
	cancelled = true
	mutex.unlock()

func is_cancelled() -> bool:
	mutex.lock()
	var result := cancelled
	mutex.unlock()
	return result

func finish() -> Dictionary:
	return worker.wait_to_finish()

func inspect(root: String) -> Dictionary:
	var state := State.new()
	var history := state.read(root, false)
	var result := {"history":history, "error":state.error, "known":false, "changed":false}
	if not state.error.is_empty(): return result
	if not history.has("source_hashes"): return result
	var hashes = history.source_hashes
	if not hashes is Dictionary or not hashes.has("mod.json"):
		result.error = "Invalid workspace source history: " + root.path_join(State.FILE)
		return result
	result.known = true
	root = ProjectSettings.globalize_path(root).simplify_path()
	for relative in hashes:
		if is_cancelled(): return {}
		var path := root.path_join(str(relative)).simplify_path()
		if not path.begins_with(root.trim_suffix("/") + "/") or not Prepared.digest_valid(hashes[relative]):
			result.error = "Invalid workspace source history: " + str(relative)
			return result
		var digest := hash_file(path)
		if is_cancelled(): return {}
		if digest != hashes[relative]:
			result.changed = true
			return result
	return result

func hash_file(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return ""
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	while file.get_position() < file.get_length():
		if is_cancelled(): return ""
		var bytes := file.get_buffer(1024 * 1024)
		if bytes.is_empty(): return ""
		hash.update(bytes)
	return hash.finish().hex_encode()
