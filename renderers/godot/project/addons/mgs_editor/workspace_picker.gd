@tool
extends VBoxContainer

signal selected(path: String, open_scene: bool)
signal failed(message: String)
var choices := OptionButton.new()
var dialog := EditorFileDialog.new()
var active := "res://mods/local"

func _ready() -> void:
	add_child(choices)
	choices.item_selected.connect(func(index): select(choices.get_item_metadata(index), true))
	var button := Button.new()
	button.text = "Open mod ZIP for editing…"
	button.pressed.connect(func(): dialog.popup_centered_ratio(0.7))
	add_child(button)
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.zip ; Mod ZIP"])
	dialog.file_selected.connect(open_zip)
	add_child(dialog)
	reload()

func reload() -> void:
	choices.clear()
	var folders: Array[String] = ["res://mods/local"]
	var names := DirAccess.get_directories_at("res://mods") if DirAccess.dir_exists_absolute("res://mods") else PackedStringArray()
	for name in names:
		var path := "res://mods/" + name
		if path not in folders and FileAccess.file_exists(path.path_join("mod.json")): folders.append(path)
	for path in folders:
		var index := choices.item_count
		choices.add_item(path.get_file())
		choices.set_item_metadata(index, path)
		if path == active: choices.select(index)

func select(path: String, open_scene: bool) -> void:
	active = path
	reload()
	selected.emit(path, open_scene)

func open_zip(path: String) -> void:
	var repository := ProjectSettings.globalize_path("res://../../..")
	var python := repository.path_join(".venv/Scripts/python.exe" if OS.has_feature("windows") else ".venv/bin/python")
	if not FileAccess.file_exists(python):
		failed.emit("Run tools/bootstrap.ps1 to prepare the mod ZIP importer.")
		return
	var output: Array = []
	var result := OS.execute(python, [repository.path_join("tools/import_godot_mod.py"), path, ProjectSettings.globalize_path("res://mods")], output, true)
	if result != 0:
		failed.emit("Cannot open mod ZIP: " + "\n".join(output))
		return
	var response = JSON.parse_string("\n".join(output))
	if not response is Dictionary or not response.get("path") is String:
		failed.emit("Invalid mod ZIP importer response: " + "\n".join(output))
		return
	var filesystem := EditorInterface.get_resource_filesystem()
	filesystem.scan()
	await get_tree().process_frame
	while filesystem.is_scanning(): await get_tree().process_frame
	select(ProjectSettings.localize_path(response.path), true)
