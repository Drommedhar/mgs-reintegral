extends SceneTree

var directory := ""
var last_update := 0
var last_phase := ""
var accepting_cancel := true
var progress_error := ""
var last_heartbeat := Time.get_unix_time_from_system()
var progress_index := 0

func write_status(data: Dictionary) -> bool:
	var path := directory.path_join("progress-%08d.json" % progress_index)
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		progress_error = "Cannot write export progress: " + path
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	if DirAccess.rename_absolute(path + ".tmp", path) != OK:
		progress_error = "Cannot update export progress: " + path
		return false
	progress_index += 1
	return true

func report(phase: String, detail: String, completed: int, total: int) -> bool:
	if not progress_error.is_empty(): return false
	var heartbeat := FileAccess.get_modified_time(directory.path_join("heartbeat"))
	last_heartbeat = maxf(last_heartbeat, float(heartbeat))
	if accepting_cancel and (FileAccess.file_exists(directory.path_join("cancel")) or Time.get_unix_time_from_system() - last_heartbeat > 15): return false
	if phase == "finalizing": accepting_cancel = false
	var now := Time.get_ticks_msec()
	if phase == last_phase and now - last_update < 100: return true
	last_phase = phase
	last_update = now
	return write_status({"phase":phase, "detail":detail, "completed":completed, "total":total, "can_cancel":accepting_cancel, "finished":false})

func run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 1:
		push_error("Export worker requires its job directory")
		quit(1)
		return
	directory = arguments[0]
	var request = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("request.json")))
	if not request is Dictionary or not request.get("root") is String or not request.get("destination") is String:
		write_status({"finished":true, "error":"Invalid export request"})
		quit(1)
		return
	var state := preload("res://addons/mgs_editor/workspace_state.gd").new()
	var error := state.export_zip(request.root, request.destination, bool(request.get("explicit_destination", false)), report)
	if not progress_error.is_empty(): error = progress_error
	if not write_status({"finished":true, "error":error}): push_error(progress_error)
	quit(0 if error.is_empty() else 1)

func _initialize() -> void:
	run.call_deferred()
