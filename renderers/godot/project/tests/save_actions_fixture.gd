extends SceneTree

func _initialize() -> void:
	var directory := ProjectSettings.globalize_path("res://../../../.local/godot-content")
	var catalog = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("catalog.json")))
	var resources := preload("res://original_ui_assets.gd").new()
	resources.configure(directory,catalog.assets,int(catalog.disc))
	var builder := preload("res://save_scene.gd").new()
	var ui := builder.create(resources)
	if ui == null:
		push_error(builder.error)
		quit(1)
		return
	var directory_out := "res://mods/save-actions-validation"
	DirAccess.make_dir_recursive_absolute(directory_out)
	for source in ["res://save_ui.gd","res://tests/fixtures/save_actions/ui_probe.gd","res://tests/fixtures/save_actions/probe.gd"]:
		var text := FileAccess.get_file_as_string(source).replace("res://save_ui.gd","save_ui.gd").replace("res://tests/fixtures/save_actions/probe.gd","probe.gd")
		FileAccess.open(directory_out.path_join(source.get_file()),FileAccess.WRITE).store_string(text)
	ui.set_script(load(directory_out.path_join("ui_probe.gd")))
	var packed := PackedScene.new()
	var error := packed.pack(ui)
	if error == OK: error=ResourceSaver.save(packed,directory_out.path_join("save_load.tscn"))
	ui.free()
	if error != OK:
		push_error("Cannot save action fixture")
		quit(1)
		return
	var manifest := directory_out.path_join("mod.json")
	FileAccess.open(manifest,FileAccess.WRITE).store_string(JSON.stringify({"schema":1,"id":"test.save-actions-ui","replacements":{},"ui":{"save_load":{"scene":"save_load.tscn"}}}))
	var exporter := preload("res://addons/mgs_editor/mod_export.gd").new()
	var zip_path := directory_out.path_join("save-actions.zip")
	var result := exporter.export_mod(manifest,zip_path,true)
	if not result.is_empty():
		push_error(result)
		quit(1)
		return
	var zip := ZIPReader.new()
	if zip.open(zip_path)!=OK:
		quit(1)
		return
	for file in zip.get_files():
		if file.ends_with("/"): continue
		if file.get_extension() not in ["gd","tscn","json"]:
			push_error("Unexpected dependency in save action ZIP: "+file)
			quit(1)
			return
		var target := directory_out.path_join("installed").path_join(file)
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		FileAccess.open(target,FileAccess.WRITE).store_buffer(zip.read_file(file))
	zip.close()
	print("MGS_SAVE_ACTIONS_FIXTURE exported and relocated")
	quit()
