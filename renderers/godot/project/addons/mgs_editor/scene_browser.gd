@tool
extends VBoxContainer

signal activated

const Data = preload("res://addons/mgs_editor/map_browser_data.gd")
var search := LineEdit.new()
var modified := CheckButton.new()
var list := Tree.new()
var detail := Label.new()
var open_button := Button.new()
var entries: Array[Dictionary] = []
var catalogs := {}
var manifest := {}
var asset_root := ""
var preferred_disc := 1
var expansion := {}

func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	search.placeholder_text = "Find maps by name, ID or type"
	search.text_changed.connect(func(_text): populate())
	add_child(search)
	modified.text = "Only maps with edits"
	modified.toggled.connect(func(_value): populate())
	add_child(modified)
	list.columns = 2
	list.hide_root = true
	list.select_mode = Tree.SELECT_ROW
	list.column_titles_visible = true
	list.set_column_title(0, "Map / variant")
	list.set_column_title(1, "Active mod")
	list.set_column_expand_ratio(0, 3)
	list.set_column_expand_ratio(1, 1)
	list.custom_minimum_size.y = 160
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.item_selected.connect(show_detail)
	list.item_activated.connect(open_selected)
	list.item_collapsed.connect(remember_expansion)
	add_child(list)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.max_lines_visible = 3
	add_child(detail)
	open_button.text = "Open map"
	open_button.pressed.connect(open_selected)
	add_child(open_button)
	populate()

func configure(sources: Dictionary, root_path: String, data: Dictionary) -> void:
	catalogs = sources
	asset_root = root_path
	set_manifest(data)

func set_manifest(data: Dictionary) -> void:
	manifest = data
	entries = Data.entries(catalogs, asset_root, manifest, preferred_disc)
	if is_node_ready(): populate()

func selected() -> Dictionary:
	var item := list.get_selected()
	return item.get_metadata(0) if item != null else {}

func remember_expansion(item: TreeItem) -> void:
	if search.text.is_empty(): expansion[item.get_metadata(1)] = not item.collapsed

func matches(entry: Dictionary) -> bool:
	return (not modified.button_pressed or entry.edited) and (search.text.is_empty() or search.text.to_lower() in (entry.label + " " + entry.kind).to_lower())

func populate() -> void:
	var selected_item := list.get_selected()
	var previous: String = selected_item.get_metadata(1) if selected_item != null else ""
	list.clear()
	var root := list.create_item()
	var groups := {}
	for entry in entries:
		if not matches(entry): continue
		if not groups.has(entry.location): groups[entry.location] = []
		groups[entry.location].append(entry)
	for location in groups:
		var variants: Array = groups[location]
		var primary: Dictionary = variants[0]
		for entry in variants:
			if entry.reason.is_empty() and (not primary.reason.is_empty() or entry.kind == "Gameplay" and primary.kind != "Gameplay"): primary = entry
		var group := row(root, primary, location, "map:" + location)
		group.set_text(1, "Edited" if variants.any(func(entry): return entry.edited) else "Original")
		if group.get_text(1) == "Edited": group.set_custom_color(1, Color(0.5, 0.9, 0.65))
		group.set_tooltip_text(0, location + "\nExpand for gameplay variants and cutscenes. Double-click to open " + primary.stage + ".")
		var stages := {}
		for entry in variants:
			if entry.has("clip"): continue
			var qualifier: String = entry.name.trim_prefix(location).strip_edges()
			qualifier = qualifier.replace("(Cutscene)", "").strip_edges()
			var label: String = entry.kind + (" " + qualifier if not qualifier.is_empty() else "") + " · " + entry.stage
			stages[entry.stage] = row(group, entry, label, Data.key(entry))
		for entry in variants:
			if entry.has("clip"):
				row(stages.get(entry.stage, group), entry, "Clip " + entry.clip.get_file() + " · " + entry.stage, Data.key(entry))
		if group.get_metadata(1) == previous: group.select(0)
		select_previous(group, previous)
	if list.get_selected() == null and root.get_child_count() > 0: root.get_child(0).select(0)
	show_detail()

func row(parent: TreeItem, entry: Dictionary, label: String, identity: String) -> TreeItem:
	var item := list.create_item(parent)
	item.set_text(0, label)
	item.set_text(1, entry.edit_label)
	item.set_metadata(0, entry)
	item.set_metadata(1, identity)
	item.collapsed = not expansion.get(identity, false) and search.text.is_empty()
	var description: String = entry.label + "\n" + entry.kind + "\n" + entry.detail
	for column in 2: item.set_tooltip_text(column, description + "\n" + entry.edit_label)
	if not entry.reason.is_empty():
		for column in 2: item.set_custom_color(column, Color(0.65, 0.65, 0.65))
	elif entry.edited: item.set_custom_color(1, Color(0.5, 0.9, 0.65))
	return item

func select_previous(parent: TreeItem, identity: String) -> void:
	for item in parent.get_children():
		if item.get_metadata(1) == identity: item.select(0)
		select_previous(item, identity)

func show_detail() -> void:
	var entry := selected()
	open_button.disabled = entry.is_empty() or not entry.reason.is_empty()
	if entry.is_empty(): detail.text = "No maps match this filter."
	else:
		detail.text = entry.label + " · " + entry.kind
		if not entry.reason.is_empty(): detail.text += "\n" + entry.reason
		elif entry.has("clip"): detail.text += "\n" + entry.detail
	detail.tooltip_text = detail.text

func open_selected() -> void:
	if not open_button.disabled: activated.emit()
