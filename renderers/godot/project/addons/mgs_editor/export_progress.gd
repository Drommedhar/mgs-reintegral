@tool
extends Window

var detail := Label.new()
var bar := ProgressBar.new()
var elapsed := Label.new()
var cancel_button := Button.new()
var directory := ""
var pid := -1
var running := false
var cancelling := false
var started := 0
var phase := ""
var progress_file := ""
var latest_status := {}

func _ready() -> void:
	name = "ExportProgress"
	title = "Export ZIP"
	visible = false
	transient = true
	exclusive = true
	unresizable = true
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]: margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size = Vector2(480, 50)
	bar.custom_minimum_size.y = 24
	bar.editor_preview_indeterminate = true
	cancel_button.text = "Cancel"
	cancel_button.pressed.connect(cancel)
	close_requested.connect(cancel)
	for control in [detail, bar, elapsed, cancel_button]: layout.add_child(control)

func begin() -> void:
	running = true
	cancelling = false
	directory = ""
	progress_file = ""
	latest_status.clear()
	phase = "saving"
	started = Time.get_ticks_msec()
	detail.text = "Saving workspace…"
	elapsed.text = ""
	bar.indeterminate = true
	bar.show_percentage = false
	cancel_button.disabled = false
	popup_centered(Vector2i(520, 205))
	# Godot 4.8.dev7 needs a size refresh after native window creation to allocate its render target.
	set_size(size)

func cancel() -> void:
	if not running or cancel_button.disabled: return
	cancelling = true
	detail.text = "Cancelling export…"
	cancel_button.disabled = true
	if directory.is_empty(): return
	var file := FileAccess.open(directory.path_join("cancel"), FileAccess.WRITE)
	if file == null:
		detail.text = "Cannot request cancellation: " + error_string(FileAccess.get_open_error())
		cancel_button.disabled = false
	else: file.store_string("cancel")

func launch(root: String, destination: String, explicit_destination: bool) -> String:
	directory = ProjectSettings.globalize_path("res://.godot/mgs_exports/%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	if DirAccess.make_dir_recursive_absolute(directory) != OK: return "Cannot create export job folder"
	var file := FileAccess.open(directory.path_join("request.json"), FileAccess.WRITE)
	if file == null: return "Cannot write export request"
	file.store_string(JSON.stringify({"root":root, "destination":destination, "explicit_destination":explicit_destination}))
	file.close()
	if not heartbeat(): return "Cannot write export heartbeat"
	pid = OS.create_process(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--log-file", directory.path_join("worker.log"), "--script", "res://addons/mgs_editor/export_worker.gd", "--", directory], false)
	return "Cannot start ZIP export worker" if pid <= 0 else ""

func heartbeat() -> bool:
	var file := FileAccess.open(directory.path_join("heartbeat"), FileAccess.WRITE)
	if file == null: return false
	file.store_string(str(Time.get_unix_time_from_system()))
	return true

func read_status() -> Dictionary:
	var records := Array(DirAccess.get_files_at(directory)).filter(func(path): return path.begins_with("progress-") and path.ends_with(".json"))
	if records.is_empty(): return latest_status
	records.sort()
	if progress_file == records.back(): return latest_status
	progress_file = records.back()
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(directory.path_join(progress_file))) != OK or not parser.data is Dictionary:
		latest_status = {"finished":true, "error":"Invalid export progress: " + directory.path_join(progress_file)}
		cancel()
	else: latest_status = parser.data
	return latest_status

func show_status(status: Dictionary) -> void:
	elapsed.text = "%d seconds elapsed" % ((Time.get_ticks_msec() - started) / 1000)
	if status.get("finished", false) or status.is_empty(): return
	phase = status.get("phase", "")
	if not cancelling: detail.text = status.get("detail", "Exporting…")
	cancel_button.disabled = cancelling or not status.get("can_cancel", true)
	var total := float(status.get("total", 0))
	bar.indeterminate = total <= 0
	bar.show_percentage = total > 0
	if total > 0: bar.value = 100.0 * float(status.get("completed", 0)) / total

func export_workspace(root: String, destination: String, explicit_destination: bool) -> String:
	var error := "Export cancelled." if cancelling else launch(root, destination, explicit_destination)
	if error.is_empty():
		while OS.is_process_running(pid):
			if not heartbeat(): cancel()
			show_status(read_status())
			await get_tree().create_timer(0.1).timeout
		var result := read_status()
		error = str(result.get("error", "Export stopped unexpectedly. See " + directory.path_join("worker.log")))
		pid = -1
	finish()
	return error

func finish() -> void:
	running = false
	hide()

func _exit_tree() -> void:
	cancel()
