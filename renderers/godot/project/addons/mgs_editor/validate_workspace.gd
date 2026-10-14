extends SceneTree

const Export = preload("res://addons/mgs_editor/mod_export.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Expected a mod manifest and validation report path")
		quit(1)
		return
	var exporter := Export.new()
	exporter.dependency_check_only = true
	var error := exporter.prepare(args[0])
	var report := FileAccess.open(args[1], FileAccess.WRITE)
	if report == null:
		push_error("Cannot write workspace validation report")
		quit(1)
		return
	report.store_string(JSON.stringify({"error":error}))
	report.close()
	quit(0 if error.is_empty() else 1)
