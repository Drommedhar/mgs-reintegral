extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var fixture := args[0] if not args.is_empty() else "options_actions"
	var directory := ProjectSettings.globalize_path("res://../../../.local/godot-content")
	var catalog = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("catalog.json")))
	var workspace := preload("res://addons/mgs_editor/mod_workspace.gd").new()
	workspace.root="res://mods/options-actions-validation-"+str(Time.get_ticks_usec())
	var authoring := preload("res://addons/mgs_editor/ui_authoring.gd").new()
	var path := authoring.open_ui(workspace,directory,catalog.assets,int(catalog.disc),"options")
	if path.is_empty():
		push_error(authoring.error)
		quit(1)
		return
	var target := path.get_base_dir()
	for file in ["ui_probe.gd","probe.gd"]:
		if DirAccess.copy_absolute("res://tests/fixtures/"+fixture+"/"+file,target.path_join(file))!=OK:
			quit(1)
			return
	var ui := load(path).instantiate() as Control
	ui.set_script(load(target.path_join("ui_probe.gd")))
	var packed := PackedScene.new()
	var status := packed.pack(ui)
	if status==OK: status=ResourceSaver.save(packed,path)
	ui.free()
	if status!=OK:
		quit(1)
		return
	var exporter := preload("res://addons/mgs_editor/mod_export.gd").new()
	var zip_path := workspace.root.path_join("options-actions.zip")
	var error := exporter.export_mod(workspace.root.path_join("mod.json"),zip_path)
	if not error.is_empty():
		push_error(error)
		quit(1)
		return
	var zip := ZIPReader.new()
	if zip.open(zip_path)!=OK:
		quit(1)
		return
	for file in zip.get_files():
		if file.ends_with("/"): continue
		if file.get_extension() not in ["gd","tscn","json"]:
			push_error("Original data in Options ZIP: "+file)
			quit(1)
			return
		var installed := workspace.root.path_join("installed").path_join(file)
		DirAccess.make_dir_recursive_absolute(installed.get_base_dir())
		FileAccess.open(installed,FileAccess.WRITE).store_buffer(zip.read_file(file))
	zip.close()
	FileAccess.open("res://.generated/options-actions-manifest.txt",FileAccess.WRITE).store_string(ProjectSettings.globalize_path(workspace.root.path_join("installed/mod.json")))
	print("MGS_OPTIONS_ACTIONS_FIXTURE "+workspace.root)
	quit()
