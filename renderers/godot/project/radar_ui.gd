@tool
extends Control

signal native_state_changed(state: Dictionary)

const Art = preload("radar_art.gd")
@export_enum("Map", "Jamming", "Evasion", "Alert", "Countdown") var preview_mode := 0:
	set(value):
		preview_mode = value
		if Engine.is_editor_hint(): update_preview.call_deferred()
@export_range(0, 255) var preview_alert_level := 190:
	set(value):
		preview_alert_level = value
		if Engine.is_editor_hint(): update_preview.call_deferred()
@export var map_background := Color8(0, 24, 24, 128)
@export var alert_background := Color8(222, 0, 0, 128)
@export var evasion_background := Color8(110, 110, 0, 128)
@export var jamming_background := Color8(0, 160, 72, 128)
var _art: RefCounted
var _layout: Dictionary = {}
var _last: Dictionary = {}

func bind_originals(resources: RefCounted) -> String:
	_art = Art.new()
	var error: String = _art.initialize(resources)
	if not error.is_empty(): return error
	for node in find_children("*", "Control", true, false):
		if not _layout.has(node):
			_layout[node] = {"position": node.position, "size": node.size, "visible": node.visible, "modulate": node.modulate}
			if node is ColorRect: _layout[node]["color"] = node.color
	get_node("Radar/Interior/AlertClip/Panel/Foreground").art = _art
	for pair in [["Warning", "a0f4"], ["WarningText", "a1bc"]]:
		var node: TextureRect = get_node("Radar/Interior/Countdown/" + pair[0])
		if node.texture == null or node.texture.has_meta("mgs_retail_derived"): node.texture = _art.textures[pair[1]]
	remember_applied()
	return ""

func detach_originals() -> void:
	remember_edits()
	for node in find_children("*", "Control", true, false):
		if node is TextureRect and node.texture != null and node.texture.has_meta("mgs_retail_derived"): node.texture = null
		if node.get("art") != null: node.art = null
		if node.get("state") != null:
			node.state = {}
			node.queue_redraw()
		if _layout.has(node):
			for property in _layout[node]: node.set(property, _layout[node][property])
	_layout.clear()
	_last.clear()
	_art = null

func apply_native_state(state: Dictionary) -> void:
	if _art == null or not state.get("active", 0): return
	remember_edits()
	var panel: Control = get_node("Radar")
	panel.position = _layout[panel].position + Vector2(state.x, state.y)
	var interior: Control = panel.get_node("Interior")
	var map_clip: Control = interior.get_node("MapClip")
	var alert_clip: Control = interior.get_node("AlertClip")
	var countdown: Control = interior.get_node("Countdown")
	var recovering: bool = state.mode == 0 and state.recovery_counter > 0
	var remaining: int = maxi(state.recovery_counter - 24, 0) if recovering else 0
	var map_width := 69 - remaining if state.mode == 0 else 0
	map_clip.size.x = map_width
	map_clip.visible = state.mode == 0
	map_clip.get_node("Background").visible = bool(state.map_visible)
	map_clip.get_node("Background").color = map_background
	for name in ["Walls", "Cones", "Contacts"]:
		var node: Control = map_clip.get_node(name)
		node.visible = bool(state.map_visible)
		node.apply_native_state(state)
	var sweep: Control = map_clip.get_node("RecoverySweep")
	sweep.visible = recovering
	sweep.position.x = 45 - (state.recovery_counter - 24)
	alert_clip.visible = state.mode in [1, 2, 3] or remaining > 0
	alert_clip.position.x = map_width
	alert_clip.size.x = 69 - map_width
	var alert_panel: Control = alert_clip.get_node("Panel")
	alert_panel.position.x = -map_width
	alert_panel.get_node("Background").color = [map_background, jamming_background, evasion_background, alert_background][mini(state.mode, 3)]
	alert_panel.get_node("Noise").apply_native_state(state)
	var foreground: Control = alert_panel.get_node("Foreground")
	foreground.visible = state.mode in [1, 2, 3]
	foreground.header_origin = _layout[foreground.get_node("Header")].position.x
	foreground.symbol_origin = _layout[foreground.get_node("Symbol")].position.x
	if foreground.visible: foreground.apply_native_state(state)
	countdown.visible = state.mode == 5
	if countdown.visible: countdown.apply_native_state(state)
	remember_applied()
	native_state_changed.emit(state.duplicate(true))

func update_preview() -> void:
	if _art == null: return
	apply_native_state({"active": 1, "mode": 5 if preview_mode == 4 else preview_mode, "tick": 12,
		"x": 0, "y": 0, "scale": 13, "map_visible": 1, "recovery_counter": 0,
		"alert_level": preview_alert_level, "console_x": 16, "console_y": 5,
		"countdown": 5400, "has_noise": 1 if preview_mode in [1,2,3] else 0, "noise_seed": 123456,
		"walls": [{"from": Vector2(-25,-20), "to": Vector2(25,-20), "kind": 0}, {"from": Vector2(-25,-20), "to": Vector2(-25,20), "kind": 0}],
		"sights": [{"points": PackedVector2Array([Vector2(4,-16),Vector2(12,0),Vector2(12,-23),Vector2(20,-16)]), "color": 0x808000, "fade_color": 0x100000}],
		"contacts": [{"position":Vector2.ZERO, "kind":0}, {"position":Vector2(12,0), "kind":1}]})

func remember_edits() -> void:
	for node in _layout:
		if not _last.has(node): continue
		for property in _layout[node]:
			var current_value = node.get(property)
			var previous = _last[node][property]
			if current_value == previous: continue
			_layout[node][property] = _layout[node][property] + current_value - previous if current_value is Vector2 else current_value

func remember_applied() -> void:
	for node in _layout:
		_last[node] = {}
		for property in _layout[node]: _last[node][property] = node.get(property)
