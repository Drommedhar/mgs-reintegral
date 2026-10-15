extends SceneTree

const Status = preload("res://addons/mgs_editor/workspace_status.gd")
const State = preload("res://addons/mgs_editor/workspace_state.gd")
var directory := "user://workspace-status-%d" % Time.get_ticks_usec()
var failures := 0

func check(value: bool, message: String) -> void:
	if value: return
	failures += 1
	push_error(message)

func write(name: String, content: String) -> void:
	FileAccess.open(directory.path_join(name), FileAccess.WRITE).store_string(content)

func inspect() -> Dictionary:
	var status := Status.new()
	check(status.start(directory) == OK, "Cannot start workspace status worker")
	while status.worker.is_alive(): await process_frame
	return status.finish()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	write("mod.json", '{"schema":1,"id":"status.test"}')
	write("paint.tres", '[gd_resource type="StandardMaterial3D" format=3]\n[resource]\nalbedo_color = Color(1,0,0,1)\n')
	var history := {"schema":1, "export_path":"saved.zip", "source_hashes":{}}
	for name in ["mod.json", "paint.tres"]:
		history.source_hashes[name] = FileAccess.get_sha256(directory.path_join(name))
	write(State.FILE, JSON.stringify(history))
	var result := await inspect()
	check(result.known and not result.changed and result.error.is_empty(), "Exported source files do not match")
	var original := FileAccess.get_file_as_string(directory.path_join("paint.tres"))
	write("paint.tres", original.replace("1,0,0,1", "0,1,0,1"))
	result = await inspect()
	check(result.changed, "Same-size immediate resource edit was missed")
	write("paint.tres", original)
	result = await inspect()
	check(not result.changed, "Restored source bytes remain dirty")
	DirAccess.remove_absolute(directory.path_join("paint.tres"))
	result = await inspect()
	check(result.changed, "Deleted export dependency was missed")
	history.source_hashes["../outside"] = "invalid"
	history.source_hashes.erase("paint.tres")
	write(State.FILE, JSON.stringify(history))
	result = await inspect()
	check(not result.error.is_empty(), "Source history accepted a path outside the workspace")
	history.erase("source_hashes")
	write(State.FILE, JSON.stringify(history))
	result = await inspect()
	check(not result.known and result.history.export_path == "saved.zip", "Legacy history lost its destination or claims a match")
	history.source_hashes = []
	write(State.FILE, JSON.stringify(history))
	result = await inspect()
	check(not result.error.is_empty(), "Malformed source history was ignored")
	write(State.FILE, "[]")
	result = await inspect()
	check(not result.error.is_empty(), "Malformed export history was ignored")
	DirAccess.remove_absolute(directory.path_join(State.FILE))
	write(".editor-source.json", '{"zip":"missing-import.zip","sha256":"original"}')
	result = await inspect()
	check(not result.known and result.history.export_path == "missing-import.zip", "Imported ZIP provenance was lost")
	for name in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)
	print("MGS_WORKSPACE_STATUS_TEST failures=%d" % failures)
	quit(1 if failures else 0)

func _initialize() -> void:
	run.call_deferred()
