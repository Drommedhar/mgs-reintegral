@tool
extends Control

signal native_state_changed(state: Dictionary)

const Art = preload("inventory_art.gd")
@export_enum("Equipped", "Items", "Weapons") var preview_mode := 0:
	set(value):
		preview_mode = value
		if Engine.is_editor_hint(): update_preview.call_deferred()
var _art: RefCounted
var _layout: Dictionary = {}
var _last: Dictionary = {}
var _clones: Dictionary = {}
var controls := preload("inventory_controls.gd").new()

func connect_provider(provider: Node) -> void:
	controls.connect_provider(self,provider)

func _input(event: InputEvent) -> void:
	controls.input(event)

func remember(node: Control) -> void:
	if node is Button: return
	if _layout.has(node): return
	_layout[node] = {"position":node.position, "size":node.size, "visible":node.visible, "self_modulate":node.self_modulate}
	if node is Label: _layout[node]["text"] = node.text
	if node is ColorRect: _layout[node]["color"] = node.color

func bind_originals(resources: RefCounted) -> String:
	resources.bind_dialogue_fonts(self)
	_art = Art.new()
	var error: String = _art.initialize(resources)
	if not error.is_empty(): return error
	var preview: Font = resources.font("mgs/ui/subtitle")
	if preview == null: return resources.error
	for node in find_children("*", "Control", true, false):
		remember(node)
		if node is Label or node is Button:
			var font: Font = node.get_theme_font("font") if node.has_theme_font_override("font") else null
			if font == null or font.has_meta("mgs_retail_derived"):
				node.add_theme_font_override("font", preview if node.name == "Preview" else _art.numbers if node.name == "Count" else _art.font)
	remember_applied()
	return ""

func restore() -> void:
	for node in _layout:
		for property in _layout[node]: node.set(property, _layout[node][property])

func remember_edits() -> void:
	for node in _layout:
		if not _last.has(node): continue
		for property in _layout[node]:
			var value = node.get(property)
			var previous = _last[node][property]
			if value != previous:
				_layout[node][property] = _layout[node][property] + value - previous if value is Vector2 else value

func remember_applied() -> void:
	for node in _layout:
		_last[node] = {}
		for property in _layout[node]: _last[node][property] = node.get(property)

func detach_originals() -> void:
	remember_edits()
	restore()
	for node in find_children("*", "Control", true, false):
		if node is TextureRect and node.texture != null and node.texture.has_meta("mgs_retail_derived"): node.texture = null
		if (node is Label or node is Button) and node.has_theme_font_override("font") and node.get_theme_font("font").has_meta("mgs_retail_derived"): node.remove_theme_font_override("font")
		if node.has_method("detach_originals"): node.detach_originals()
		if node.get("art") != null: node.art = null
		if node.get("state") != null:
			node.state = {}
			node.queue_redraw()
	for clone in _clones.values(): clone.free()
	_clones.clear()
	_layout.clear()
	_last.clear()
	_art = null

func panel_for(index: int, side: int) -> Control:
	var template: Control = get_node("Item" if side == 0 else "Weapon")
	if index < 2: return template
	var slot := "%d_%d" % [side, index]
	if not _clones.has(slot):
		var clone := template.duplicate(Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS | Node.DUPLICATE_USE_INSTANTIATION) as Control
		clone.name = "NativePanel%d" % index
		add_child(clone)
		_clones[slot] = clone
		remember(clone)
		for node in clone.find_children("*", "Control", true, false): remember(node)
		if controls.provider!=null:
			for button in clone.find_children("*","Button",true,false): controls.connect_button(button)
	return _clones[slot]

func apply_native_state(state: Dictionary) -> void:
	if _art == null: return
	remember_edits()
	restore()
	get_node("Item").hide()
	get_node("Weapon").hide()
	for clone in _clones.values(): clone.hide()
	prepare_panels(state.get("panels", []))
	var used := [false, false]
	var extra := 2
	for index in state.get("panels", []).size():
		var panel: Dictionary = state.panels[index]
		var slot: int = panel.side if not used[panel.side] else extra
		if used[panel.side]: extra += 1
		var node := panel_for(slot, panel.side)
		used[panel.side] = true
		node.visible = _layout[get_node("Item" if panel.side == 0 else "Weapon")].visible
		node.z_index = 32 - index
		node.position = _layout[get_node("Item" if panel.side == 0 else "Weapon")].position + panel.position - Vector2(16 if panel.side == 0 else 260,184)
		node.apply_native_state(panel, _art)
	apply_description(state.get("description", {}), state.get("shape", -1))
	remember_applied()
	controls.refresh()
	native_state_changed.emit(state.duplicate(true))

func prepare_panels(panels: Array) -> void:
	var used := [false, false]
	var extra := 2
	for panel in panels:
		var slot: int = panel.side if not used[panel.side] else extra
		if used[panel.side]: extra += 1
		panel_for(slot, panel.side)
		used[panel.side] = true

func apply_description(state: Dictionary, shape: int) -> void:
	var panel: Control = get_node("Description")
	panel.visible = panel.visible and state.get("active", false)
	if not panel.visible: return
	panel.position += state.position - Vector2(86,72)
	panel.get_node("Title").text = "EQUIP" if state.kind == 0 else "WEAPON"
	var text: Control = panel.get_node("Text")
	var local := state.duplicate()
	local.position = Vector2.ZERO
	text.apply_native_state(local)
	panel.get_node("Preview").visible = state.get("layout", {}).is_empty()
	var key: TextureRect = panel.get_node("PalKey")
	key.visible = key.visible and shape >= 0
	if key.visible and (key.texture == null or key.texture.has_meta("mgs_retail_derived")):
		key.texture = _art.textures[34 + shape * 2]
		key.size = key.texture.get_size()

func update_preview() -> void:
	var item := {"side":0,"id":13,"position":Vector2(16,184),"icon":22,"flags":4,"quantity":3,"maximum":5,"level":1,"magazine":0,"magazine_max":0,"burst":0,"name":"RATION"}
	var weapon := {"side":1,"id":0,"position":Vector2(260,184),"icon":1,"flags":128,"quantity":12,"maximum":46,"level":0,"magazine":8,"magazine_max":12,"burst":0,"name":"SOCOM"}
	if preview_mode == 2: weapon.flags = 4
	apply_native_state({"panels":[item,weapon],"shape":-1,
		"description":{"active":preview_mode != 0,"visible":true,"kind":1 if preview_mode == 2 else 0,
		"position":Vector2(44 if preview_mode == 2 else 86,72),"layout":{}}})
