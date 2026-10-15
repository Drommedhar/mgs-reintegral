@tool
extends VBoxContainer

const ModResources = preload("res://mod_resources.gd")

signal changed
signal reported(message: String)
signal open_requested(path: String)
var workspace: RefCounted
var list := Tree.new()
var search := LineEdit.new()
var dialog := ConfirmationDialog.new()
var picker := EditorFileDialog.new()
var resource_name := LineEdit.new()
var resource_path := LineEdit.new()
var remove_button := Button.new()
var open_button := Button.new()
var edit_button := Button.new()
var previous := ""

func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	search.placeholder_text = "Find mod resources by name or path"
	search.text_changed.connect(func(_text): refresh())
	add_child(search)
	list.hide_root = true
	list.columns = 2
	list.column_titles_visible = true
	list.set_column_title(0, "Resource name")
	list.set_column_title(1, "File")
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.item_selected.connect(update_selection)
	list.item_activated.connect(open_selected)
	add_child(list)
	var row := HBoxContainer.new()
	add_child(row)
	var add_button := Button.new()
	add_button.text = "Add…"
	add_button.pressed.connect(func(): open_entry("", ""))
	row.add_child(add_button)
	open_button.text = "Open"
	open_button.pressed.connect(open_selected)
	row.add_child(open_button)
	edit_button.text = "Edit entry…"
	edit_button.pressed.connect(edit_selected)
	row.add_child(edit_button)
	remove_button.text = "Remove entry"
	remove_button.pressed.connect(remove_selected)
	row.add_child(remove_button)
	var note := Label.new()
	note.text = "Name files that scripts load at runtime. Their dependencies are included in the ZIP. Open edits the asset; Edit entry changes its name or path. Removing an entry keeps its file."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(note)
	dialog.title = "Mod resource"
	dialog.ok_button_text = "Save entry"
	var fields := VBoxContainer.new()
	fields.custom_minimum_size.x = 380
	resource_name.placeholder_text = "Name used by scripts, e.g. lamps/alarm"
	fields.add_child(resource_name)
	resource_path.placeholder_text = "File inside this mod"
	fields.add_child(resource_path)
	var browse := Button.new()
	browse.text = "Choose file…"
	browse.pressed.connect(func():
		picker.current_dir = workspace.root
		picker.popup_centered_ratio(0.7))
	fields.add_child(browse)
	dialog.add_child(fields)
	dialog.confirmed.connect(save_entry)
	add_child(dialog)
	picker.access = FileDialog.ACCESS_RESOURCES
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.file_selected.connect(func(path):
		resource_path.text = path.trim_prefix(workspace.root.trim_suffix("/") + "/")
		if resource_name.text.is_empty(): resource_name.text = path.get_file().get_basename())
	add_child(picker)
	refresh()

func selected() -> String:
	var item := list.get_selected()
	return str(item.get_metadata(0)) if item != null else ""

func refresh() -> void:
	if not is_node_ready(): return
	var active := selected()
	list.clear()
	var root := list.create_item()
	var entries: Dictionary = workspace.manifest().get("resources", {})
	var names := entries.keys()
	names.sort()
	for key in names:
		if not entries[key] is Dictionary or not entries[key].get("path") is String:
			reported.emit("Invalid mod resource entry: " + str(key))
			continue
		var path: String = entries[key].get("path", "")
		if not search.text.is_empty() and search.text.to_lower() not in (str(key) + " " + path).to_lower(): continue
		var item := list.create_item(root)
		item.set_text(0, key)
		item.set_text(1, path)
		item.set_metadata(0, key)
		item.set_tooltip_text(1, path)
		if key == active: item.select(0)
	update_selection()

func update_selection() -> void:
	for button in [open_button, edit_button, remove_button]:
		button.disabled = selected().is_empty()

func open_selected() -> void:
	var key := selected()
	if key.is_empty(): return
	var entries: Dictionary = workspace.manifest().get("resources", {})
	var error := ModResources.validate(workspace.root, {key:entries[key]})
	if not error.is_empty(): reported.emit(error); return
	open_requested.emit(ModResources.asset_path(workspace.root, entries[key].path))

func open_entry(key: String, path: String) -> void:
	previous = key
	resource_name.text = key
	resource_path.text = path
	dialog.popup_centered()

func edit_selected() -> void:
	var key := selected()
	if not key.is_empty(): open_entry(key, workspace.manifest().get("resources", {})[key].path)

func save_entry() -> void:
	var path := resource_path.text.strip_edges()
	if not path.is_absolute_path(): path = workspace.root.path_join(path)
	if not workspace.register_resource(resource_name.text.strip_edges(), path, previous):
		reported.emit(workspace.error)
		dialog.popup_centered()
		return
	refresh()
	changed.emit()

func remove_selected() -> void:
	if selected().is_empty(): return
	if not workspace.remove_resource(selected()): reported.emit(workspace.error)
	else:
		refresh()
		changed.emit()
