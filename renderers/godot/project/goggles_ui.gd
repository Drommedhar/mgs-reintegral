@tool
extends Control

signal native_state_changed(state: Dictionary)

@export_enum("Night vision:1", "Thermal vision:2") var preview_mode := 1:
	set(value):
		preview_mode = value
		if Engine.is_editor_hint(): update_preview.call_deferred()
@export_range(0, 4095) var preview_heading := 0:
	set(value):
		preview_heading = value
		if Engine.is_editor_hint(): update_preview.call_deferred()
var _resources: RefCounted
var _roles: Dictionary = {}
var _origins: Dictionary = {}
var _drawn: Dictionary = {}
var _original_fonts: Dictionary = {}

func bind_originals(resources: RefCounted) -> String:
	_resources = resources
	_roles.clear()
	for node in find_children("*", "Control", true, false):
		if node.has_meta("mgs_ui_role"):
			var role: String = node.get_meta("mgs_ui_role")
			if not _roles.has(role): _roles[role] = []
			_roles[role].append(node)
			if not _origins.has(node): _origins[node] = values(node)
		if node.has_meta("mgs_ui_font") and not has_authored_font(node):
			var font: FontFile = resources.font(node.get_meta("mgs_ui_font"))
			if font == null: return resources.error
			node.add_theme_font_override("font", font)
			_original_fonts[node] = font
		if node.has_method("bind") and node.get("source_id") != null:
			var error: String = node.bind(resources)
			if not error.is_empty(): return error
	return ""

func has_authored_font(node: Control) -> bool:
	if node.has_theme_font_override("font"): return true
	var variation := node.theme_type_variation
	var parent: Node = node
	while parent != null:
		if parent is Control and parent.theme != null:
			var theme: Theme = parent.theme
			if theme.default_font != null or theme.has_font("font", "Label") or (not variation.is_empty() and theme.has_font("font", variation)): return true
		parent = parent.get_parent()
	return false

func update_preview() -> void:
	if _resources == null: return
	detach_originals()
	var error := bind_originals(_resources)
	if not error.is_empty():
		push_error(error)
		return
	apply_native_state({"mode": preview_mode, "active": true, "hud": true, "scan": true, "heading": preview_heading, "layers": 7, "offsets": [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]})

func detach_originals() -> void:
	for node in _original_fonts:
		if is_instance_valid(node) and node.get_theme_font("font") == _original_fonts[node]: node.remove_theme_font_override("font")
	_original_fonts.clear()
	for node in _origins:
		if not is_instance_valid(node): continue
		var before: Dictionary = _origins[node]
		var drawn: Dictionary = _drawn.get(node, before)
		node.position -= drawn.position - before.position
		node.size -= drawn.size - before.size
		if node.visible == drawn.visible: node.visible = before.visible
		if node is Label and node.text == drawn.text: node.text = before.text
	_origins.clear()
	_drawn.clear()

func values(node: Control) -> Dictionary:
	return {"position": node.position, "size": node.size, "visible": node.visible, "text": node.text if node is Label else ""}

func apply_native_state(state: Dictionary) -> void:
	var mode: int = state.get("mode", 0)
	var heading: int = state.get("heading", 0)
	for role in _roles:
		for node in _roles[role]:
			if not is_instance_valid(node): continue
			var before: Dictionary = _origins[node]
			match role:
				"night": node.visible = before.visible and mode == 1
				"thermal": node.visible = before.visible and mode == 2
				"hud": node.visible = before.visible and state.get("hud", false)
				"scan": node.visible = before.visible and state.get("scan", false)
				"layer":
					var index: int = node.get_meta("mgs_ui_index")
					node.visible = before.visible and bool(state.get("layers", 0) & (1 << index))
					node.position = before.position + state.get("offsets", [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])[index]
				"vector":
					node.text = str([8 * (heading & 2047), 4 * heading, 16 * (heading & 1023)][int(node.get_meta("mgs_ui_index"))])
				"bar", "cap": update_bar(node, before, heading, role == "cap")
				"heading", "tick": update_heading(node, before, heading, role == "tick")
			_drawn[node] = values(node)
	native_state_changed.emit(state.duplicate(true))

func update_bar(node: Control, before: Dictionary, heading: int, cap: bool) -> void:
	var values := [((heading + 1024) & 2047) >> 5, heading >> 6, ((heading - 1024) & 1023) >> 4]
	var length: int = values[int(node.get_meta("mgs_ui_index"))]
	if length < 32: length = 64 - length
	node.position.y = before.position.y - length
	if not cap: node.size.y = length

func update_heading(node: Control, before: Dictionary, heading: int, tick: bool) -> void:
	var offset := (heading % 64) * 24 / 64 + 160
	var index: int = node.get_meta("mgs_ui_index")
	var x := offset % 24 + index * 24
	var value := heading / 64 + offset / 24 - index
	if value >= 65: value -= 64
	elif value < 0: value = -value
	elif value > 32: value = 64 - value
	node.visible = before.visible and x >= 20 and x < 300
	node.position.x = before.position.x + x
	if not tick: node.text = "%02d" % value
