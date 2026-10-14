@tool
extends VBoxContainer

var tabs := TabContainer.new()

func _init() -> void:
	name = "MGS Visuals"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size.x = 300
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.use_hidden_tabs_for_min_size = false
	add_child(tabs)

func page(title: String, parent: TabContainer = tabs) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = title
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	return box

static func sub_tabs(parent: Control) -> TabContainer:
	var control := TabContainer.new()
	control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	control.use_hidden_tabs_for_min_size = false
	parent.add_child(control)
	return control

static func button(parent: Control, title: String, callback: Callable) -> Button:
	var control := Button.new()
	control.text = title
	control.pressed.connect(callback)
	parent.add_child(control)
	return control

static func note(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label
