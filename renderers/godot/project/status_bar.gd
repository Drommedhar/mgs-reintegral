@tool
extends Control

signal native_state_changed(state: Dictionary)

@export_enum("Other:0", "Life:1", "Oxygen:2") var kind := 1
@export var follow_native_position := true
@export var native_origin := Vector2(16, 16)
@export var use_native_colors := false
@export var use_native_name := false
@export var damage_text_tint := Color(1, 48.0 / 255, 48.0 / 255)
var _authored: Dictionary = {}
var _drawn: Dictionary = {}
var _fonts: Dictionary = {}
var _gradient: GradientTexture2D
var _original_gradient: Texture2D
var _drawn_colors := PackedColorArray()

func authored_font(node: Control) -> bool:
	if node.has_theme_font_override("font"): return true
	var variation := node.theme_type_variation
	var parent: Node = node
	while parent != null:
		if parent is Control and parent.theme != null:
			var custom: Theme = parent.theme
			if custom.default_font != null or custom.has_font("font", "Label") or (not variation.is_empty() and custom.has_font("font", variation)): return true
		parent = parent.get_parent()
	return false

func bind_originals(resources: RefCounted) -> String:
	for node in [self] + find_children("*", "Control", true, false):
		if not _authored.has(node): _authored[node] = values(node)
		if node is Label and node.has_meta("mgs_ui_font") and not authored_font(node):
			var font: FontFile = resources.font(node.get_meta("mgs_ui_font"))
			if font == null: return resources.error
			node.add_theme_font_override("font", font)
			_fonts[node] = font
	return ""

func values(node: Control) -> Dictionary:
	return {"position": node.position, "size": node.size, "visible": node.visible,
		"text": node.text if node is Label else "", "modulate": node.self_modulate}

func detach_originals() -> void:
	for node in _fonts:
		if is_instance_valid(node) and node.get_theme_font("font") == _fonts[node]: node.remove_theme_font_override("font")
	_fonts.clear()
	for node in _authored:
		if not is_instance_valid(node): continue
		var before: Dictionary = _authored[node]
		var drawn: Dictionary = _drawn.get(node, before)
		node.position -= drawn.position - before.position
		node.size -= drawn.size - before.size
		if node.visible == drawn.visible: node.visible = before.visible
		if node.self_modulate == drawn.modulate: node.self_modulate = before.modulate
		if node is Label and node.text == drawn.text: node.text = before.text
	if _gradient != null:
		var fill := get_node_or_null("Fill/Gradient") as TextureRect
		if fill != null and fill.texture == _gradient:
			if _gradient.gradient.colors != _drawn_colors:
				var edited: GradientTexture2D = _gradient.duplicate(true)
				for index in mini(_drawn_colors.size(), edited.gradient.get_point_count()):
					if edited.gradient.get_color(index) == _drawn_colors[index]: edited.gradient.set_color(index, _original_gradient.gradient.get_color(index))
				fill.texture = edited
			else: fill.texture = _original_gradient
	_gradient = null
	_original_gradient = null
	_authored.clear()
	_drawn.clear()

func apply_native_state(state: Dictionary) -> void:
	if _authored.is_empty(): return
	var maximum: int = state.maximum / 8
	var value: int = (int(state.value) + 7) / 8
	var rest: int = mini(state.rest, state.maximum)
	for node in _authored:
		if not is_instance_valid(node): continue
		var before: Dictionary = _authored[node]
		var role: String = node.get_meta("mgs_bar_role", "")
		if node == self and follow_native_position: node.position = before.position + state.position - native_origin
		match role:
			"background", "top", "bottom": node.size.x = before.size.x + maximum - 128
			"right": node.position.x = before.position.x + maximum - 128
			"fill", "gradient": node.size.x = maxf(0, before.size.x + value - 128)
			"damage":
				node.position.x = before.position.x + int(state.value) / 8
				node.size.x = maxf(0, before.size.x + (rest - int(state.value)) / 8)
				node.visible = before.visible and rest > state.value
			"label":
				if use_native_name: node.text = state.name
				node.self_modulate = before.modulate * (damage_text_tint if state.damage else Color.WHITE)
			"label_background":
				var label := get_node_or_null("Name") as Label
				if label != null and use_native_name: node.size.x = before.size.x + label.get_theme_font("font").get_string_size(state.name, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x - label.get_theme_font("font").get_string_size(_authored[label].text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
		if role in ["background", "fill", "damage", "left", "right", "gradient"]: node.size.y = before.size.y + int(state.height) - (4 if kind == 2 else 5)
		if role == "bottom": node.position.y = before.position.y + int(state.height) - (4 if kind == 2 else 5)
		_drawn[node] = values(node)
	update_colors(state)
	native_state_changed.emit(state.duplicate(true))

func update_colors(state: Dictionary) -> void:
	var fill := get_node_or_null("Fill/Gradient") as TextureRect
	if fill == null or not fill.texture is GradientTexture2D: return
	if _gradient == null:
		_original_gradient = fill.texture
		_gradient = fill.texture.duplicate(true)
		fill.texture = _gradient
	if _original_gradient.gradient.get_point_count() != 2: return
	var left: Color = _original_gradient.gradient.get_color(0)
	var right: Color = _original_gradient.gradient.get_color(1)
	if use_native_colors:
		left = unpack_color(state.left)
		right = unpack_color(state.right)
	var width: int = (int(state.value) + 7) / 8
	var endpoint := Color(0, 0, 0, right.a)
	for channel in 3:
		var start := roundi(left[channel] * 255)
		var end := roundi(right[channel] * 255)
		endpoint[channel] = float((start + (end - start) * width / 128) & 255) / 255
	if _gradient.gradient.get_color(0) != left: _gradient.gradient.set_color(0, left)
	if _gradient.gradient.get_color(1) != endpoint: _gradient.gradient.set_color(1, endpoint)
	_drawn_colors = _gradient.gradient.colors.duplicate()

func unpack_color(color: int) -> Color:
	return Color8(color & 255, (color >> 8) & 255, (color >> 16) & 255)
