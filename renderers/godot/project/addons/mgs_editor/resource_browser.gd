@tool
extends VBoxContainer

signal activated(identity: String)

var definitions: Array[Dictionary] = []
var manifest := {}
var search := LineEdit.new()
var list := Tree.new()
var detail := Label.new()
var open_button := Button.new()

func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	search.placeholder_text = "Search " + name.to_lower()
	search.text_changed.connect(func(_text): populate())
	add_child(search)
	list.hide_root = true
	list.columns = 2
	list.select_mode = Tree.SELECT_ROW
	list.set_column_expand_ratio(0, 3)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.custom_minimum_size.y = 120
	list.item_selected.connect(show_detail)
	list.item_activated.connect(open_selected)
	add_child(list)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.max_lines_visible = 3
	add_child(detail)
	open_button.text = "Open selected"
	open_button.pressed.connect(open_selected)
	add_child(open_button)
	populate()

func set_manifest(data: Dictionary) -> void:
	manifest = data
	if is_node_ready(): populate()

func selected() -> Dictionary:
	var item := list.get_selected()
	return item.get_metadata(0) if item != null and item.get_metadata(0) is Dictionary else {}

func populate() -> void:
	var previous: String = selected().get("id", "")
	list.clear()
	var root := list.create_item()
	var groups := {}
	for definition in definitions:
		if not search.text.is_empty() and search.text.to_lower() not in (definition.label + " " + definition.group).to_lower(): continue
		if not groups.has(definition.group):
			var group := list.create_item(root)
			group.set_text(0, definition.group)
			for column in 2: group.set_selectable(column, false)
			groups[definition.group] = group
		var item := list.create_item(groups[definition.group])
		item.set_text(0, definition.label)
		var edited: bool = manifest.get(definition.section, {}).has(definition.get("key", definition.id))
		item.set_text(1, "Edited" if edited else "Original")
		if edited: item.set_custom_color(1, Color(0.5, 0.9, 0.65))
		item.set_metadata(0, definition)
		item.set_tooltip_text(0, definition.detail)
		if definition.id == previous: item.select(0)
	show_detail()

func show_detail() -> void:
	var entry := selected()
	open_button.disabled = entry.is_empty()
	detail.text = entry.get("detail", "Select an entry to edit it in the Inspector or scene editor.")
	detail.tooltip_text = detail.text

func open_selected() -> void:
	var entry := selected()
	if not entry.is_empty(): activated.emit(entry.id)
