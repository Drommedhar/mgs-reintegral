@tool
extends VBoxContainer

signal changed
signal reported(message: String)
const Profile = preload("res://mod_profile.gd")
const Layout = preload("res://addons/mgs_editor/dock_layout.gd")
const STORAGE = "res://.godot/mgs_mod_profile.json"
var profile := Profile.new()
var list := Tree.new()
var diagnostics := RichTextLabel.new()
var dialog := EditorFileDialog.new()
var active_manifest := ""
var updating := false

func _ready() -> void:
	Layout.note(self, "Enabled mods for Profile Preview and native Run. Higher priority wins within a scope; exact scenarios override shared maps.")
	list.columns = 2
	list.hide_root = true
	list.column_titles_visible = true
	list.set_column_title(0, "Mod")
	list.set_column_title(1, "Priority")
	list.set_column_expand(1, false)
	list.set_column_custom_minimum_width(1, 70)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.custom_minimum_size.y = 130
	list.item_edited.connect(edit_entry)
	add_child(list)
	Layout.button(self, "Add mod manifest…", func(): dialog.popup_centered_ratio(0.7))
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(["mod.json ; Mod manifest"])
	dialog.file_selected.connect(add_manifest)
	add_child(dialog)
	diagnostics.custom_minimum_size.y = 90
	diagnostics.size_flags_vertical = Control.SIZE_EXPAND_FILL
	diagnostics.selection_enabled = true
	add_child(diagnostics)
	if FileAccess.file_exists(STORAGE):
		var error := profile.read(STORAGE)
		if not error.is_empty(): reported.emit(error)
	refresh()

func set_active(path: String) -> void:
	var selected := ProjectSettings.localize_path(path.replace("\\", "/")).simplify_path()
	var switched := selected != active_manifest
	active_manifest = selected
	if not FileAccess.file_exists(active_manifest): return
	var error := profile.add(active_manifest)
	if not error.is_empty():
		reported.emit(error)
		return
	for entry in profile.entries:
		if entry.manifest == active_manifest: entry.enabled = true
		elif switched and manifest_id(entry.manifest) == manifest_id(active_manifest): entry.enabled = false
	persist(false)

func manifest_id(path: String) -> String:
	if not FileAccess.file_exists(path): return ""
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return str(data.get("id", "")) if data is Dictionary else ""

func add_manifest(path: String) -> void:
	var error := profile.add(path)
	if not error.is_empty(): reported.emit(error)
	else: persist()

func refresh() -> void:
	updating = true
	list.clear()
	var root := list.create_item()
	for index in profile.entries.size():
		var entry: Dictionary = profile.entries[index]
		var item := list.create_item(root)
		item.set_metadata(0, index)
		var data = JSON.parse_string(FileAccess.get_file_as_string(entry.manifest)) if FileAccess.file_exists(entry.manifest) else {}
		var identity: String = str(data.get("id", entry.manifest)) if data is Dictionary else entry.manifest
		item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		item.set_text(0, identity + (" (editing)" if entry.manifest == active_manifest else ""))
		item.set_checked(0, entry.enabled)
		item.set_editable(0, entry.manifest != active_manifest)
		item.set_tooltip_text(0, entry.manifest)
		item.set_cell_mode(1, TreeItem.CELL_MODE_RANGE)
		item.set_range_config(1, -1000000, 1000000, 1)
		item.set_range(1, entry.priority)
		item.set_editable(1, true)
	updating = false

func edit_entry() -> void:
	if updating: return
	var item := list.get_edited()
	if item == null: return
	update_entry(item.get_metadata(0), item.is_checked(0), item.get_range(1))

func update_entry(index: int, enabled: bool, priority: float) -> void:
	var entry: Dictionary = profile.entries[index]
	entry.enabled = enabled or entry.manifest == active_manifest
	entry.priority = priority
	persist()

func persist(emit_change: bool = true) -> void:
	var error := profile.save(STORAGE)
	refresh()
	if not error.is_empty(): reported.emit(error)
	elif emit_change: changed.emit()

func show_diagnostics(messages: PackedStringArray) -> void:
	diagnostics.text = "No overlapping targets in this preview." if messages.is_empty() else "\n\n".join(messages)
