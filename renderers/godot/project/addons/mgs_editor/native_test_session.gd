@tool
extends Node

signal changed(message: String, active: bool)

var directory := ""
var pid := -1
var last_status := ""
var elapsed := 0.0

func active() -> bool:
	return pid > 0 and OS.is_process_running(pid)

func start(stage: String, manifest: String, disc: int = 1, profile: RefCounted = null) -> String:
	if active(): return "Stop the current native test before starting another."
	if disc not in [1, 2]: return "Native test requires original Disc 1 or 2."
	if not FileAccess.file_exists(manifest): return "Save the mod workspace before testing."
	var repository := ProjectSettings.globalize_path("res://../../..")
	directory = repository.path_join("build/godot-editor-runs/%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	if DirAccess.make_dir_recursive_absolute(directory) != OK: return "Cannot create native test session folder."
	var arguments := ["-NoProfile", "-File", repository.path_join("tools/run-godot-editor.ps1"),
		"-SessionDirectory", directory, "-Stage", stage, "-Manifest", ProjectSettings.globalize_path(manifest),
		"-StartDisc", str(disc), "-OwnerPid", str(OS.get_process_id())]
	if profile != null:
		var path := directory.path_join("mod-profile.json")
		var profile_error: String = profile.save(path, true)
		if not profile_error.is_empty(): return profile_error
		arguments.append_array(["-ModProfile", path])
	pid = OS.create_process(preload("res://addons/mgs_editor/sdk_paths.gd").powershell(), arguments, false)
	if pid <= 0: return "Cannot start PowerShell. Install PowerShell 7 and check tools/run-godot-editor.ps1."
	last_status = ""
	changed.emit("Starting native test…", true)
	return ""

func stop() -> void:
	if not active(): return
	var file := FileAccess.open(directory.path_join("stop"), FileAccess.WRITE)
	if file == null:
		changed.emit("Cannot write the stop request; close the game window.", true)
		return
	file.store_string("stop\n")
	changed.emit("Stopping native test…", true)

func _process(delta: float) -> void:
	if pid <= 0: return
	elapsed += delta
	if elapsed < 0.25: return
	elapsed = 0
	var path := directory.path_join("status.json")
	if FileAccess.file_exists(path):
		var content := FileAccess.get_file_as_string(path)
		if content != last_status:
			var data = JSON.parse_string(content)
			if data is Dictionary:
				last_status = content
				changed.emit(str(data.get("message", "Native test status unavailable")), active())
	if not active():
		pid = -1
		if last_status.is_empty(): changed.emit("Native runner stopped without status. Open test logs for details.", false)
		else: changed.emit(str(JSON.parse_string(last_status).get("message", "Native test stopped")), false)

func _exit_tree() -> void:
	stop()
