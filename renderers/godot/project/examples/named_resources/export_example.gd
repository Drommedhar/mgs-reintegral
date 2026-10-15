extends SceneTree

func _initialize() -> void:
	var source := "res://examples/named_resources/mod.json"
	var destination := "res://../../../build/mod-exports/sdk-named-resources.zip"
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() == 1: destination = arguments[0]
	var exporter := preload("res://addons/mgs_editor/mod_export.gd").new()
	var error := exporter.export_mod(source, destination)
	if not error.is_empty(): push_error(error)
	else: print("MGS_NAMED_RESOURCE_EXAMPLE " + ProjectSettings.globalize_path(destination))
	quit(0 if error.is_empty() else 1)
