@tool
extends Control

@export var alert_color := Color8(137, 37, 24)
@export var evasion_color := Color8(137, 71, 24)
@export var jamming_color := Color8(24, 137, 51)
var art: RefCounted
var state: Dictionary = {}
var header_origin := 12.0
var symbol_origin := 9.0

func apply_native_state(value: Dictionary) -> void:
	state = value
	if art == null or state.is_empty(): return
	var jam: bool = state.mode == 1
	var color := jamming_color if jam else alert_color if state.mode == 3 else evasion_color
	var pulse: int = state.tick % 16
	var header_color := color * (1.0 - pulse / 8.0 if pulse < 8 else 1.0)
	header_color.a = 1.0
	var header_rect := Rect2(10, 38, 58, 7) if jam else Rect2(0, 12, 44, 7) if state.mode == 3 else Rect2(0, 19, 58, 7)
	var header := set_art("Header", "art", header_rect, header_color)
	if header:
		header.size = header_rect.size
		header.position.x = header_origin + 22 - header_rect.size.x / 2
	set_art("Underline", "art", Rect2(60, 19, 36, 3), header_color)
	var symbol := set_art("Symbol", "art", Rect2(10, 26, 58, 12) if jam else Rect2(0 if state.mode == 3 else 28, 0, 28, 12), color)
	if symbol:
		symbol.size = Vector2(58 if jam else 28, 12)
		symbol.position.x = symbol_origin - (3 if jam else 0)
	get_node("Counter").visible = not jam
	var level: int = 256 if state.alert_level == 255 else state.alert_level
	var number := "%04d" % int(level * 9999 / 256)
	for index in 4:
		set_art("Counter/Digit%d" % index, "alert" if state.mode == 3 else "evasion", Rect2(int(number[index]) * 10, 0, 10, 16), Color(128.0 / 255, 128.0 / 255, 128.0 / 255))
	for node in get_node("Counter").get_children():
		if node is ColorRect: node.color = color
	queue_redraw()

func _draw() -> void:
	if art == null or state.is_empty() or state.mode == 0: return
	var jam: bool = state.mode == 1
	var color := jamming_color if jam else alert_color if state.mode == 3 else evasion_color
	var pulse: int = state.tick % 16
	var header_color := color * (1.0 - pulse / 8.0 if pulse < 8 else 1.0)
	header_color.a = 1.0
	var width := 58 if jam or state.mode == 2 else 44
	var left := 34 - int(width / 2)
	draw_rect(Rect2(0, 1, left, 7), header_color)
	draw_rect(Rect2(left + width, 1, 69 - left - width, 7), header_color)
	draw_rect(Rect2(0, 8, 16, 3), header_color)
	draw_rect(Rect2(52, 8, 17, 3), header_color)
	var rows: int = mini(state.console_y, 7 if jam else 5)
	var x := 6 if jam else 38
	var y := (30 if jam else 14) + rows * 2
	var tint := color * Color(255.0 / 128, 255.0 / 128, 255.0 / 128, 1)
	for row in range(rows + 1):
		var length: int = state.console_x if row == 0 else 56 if jam else 24
		var v: int = (state.console_y - row + 16) % 16
		var first := mini(length, 28)
		if first > 0: draw_texture_rect_region(art.textures.art, Rect2(x, y - row * 2, first, 1), Rect2(68, 22 + v, first, 1), tint)
		if length > 28: draw_texture_rect_region(art.textures.art, Rect2(x + 28, y - row * 2, length - 28, 1), Rect2(68, 22 + (v + 3) % 16, length - 28, 1), tint)

func set_art(path: String, source: String, rect: Rect2, tint: Color) -> TextureRect:
	var node := get_node(path) as TextureRect
	if node.texture != null and not node.texture.has_meta("mgs_retail_derived"): return null
	node.texture = art.region(source, rect)
	node.modulate = tint * Color(255.0 / 128, 255.0 / 128, 255.0 / 128, 1)
	return node
