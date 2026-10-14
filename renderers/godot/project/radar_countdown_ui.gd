@tool
extends Control

const MASKS := [0x77, 0x24, 0x5d, 0x6d, 0x2e, 0x6b, 0x7b, 0x25, 0x7f, 0x6f]
const LARGE := [Rect2(1,0,7,2), Rect2(0,1,2,7), Rect2(7,1,2,7), Rect2(1,7,7,2), Rect2(0,9,2,6), Rect2(7,9,2,6), Rect2(1,14,7,2)]
const SMALL := [Rect2(1,0,5,2), Rect2(0,1,2,5), Rect2(5,1,2,5), Rect2(1,5,5,2), Rect2(0,7,2,5), Rect2(5,7,2,5), Rect2(1,11,5,2)]
@export var active_color := Color8(137, 37, 24)
@export var inactive_color := Color8(24, 8, 0)
var state: Dictionary = {}

func apply_native_state(value: Dictionary) -> void:
	state = value
	var pulse: int = state.get("tick", 0) % 16
	get_node("Warning").modulate = Color.WHITE * (1.0 if pulse >= 8 else 1.0 - pulse / 8.0)
	get_node("Warning").modulate.a = 1.0
	queue_redraw()

func _draw() -> void:
	if state.is_empty(): return
	var ticks: int = maxi(state.get("countdown", 0), 0)
	var remaining := int(ticks * 100 / 30)
	var digits := "%02d%02d%02d" % [int(remaining / 6000) % 100, int(remaining / 100) % 60, remaining % 100]
	var points := [Vector2(3,32), Vector2(13,32), Vector2(27,32), Vector2(37,32), Vector2(51,35), Vector2(59,35)]
	for index in 6:
		var mask: int = MASKS[int(digits[index])]
		var segments: Array = LARGE if index < 4 else SMALL
		for segment in 7:
			var rect: Rect2 = segments[segment]
			rect.position += points[index]
			draw_rect(rect, active_color if mask & (1 << segment) else inactive_color)
	var colon_color := inactive_color if remaining % 100 < 50 else active_color
	for point in [Vector2(24,36), Vector2(24,43), Vector2(48,37), Vector2(48,44)]: draw_rect(Rect2(point, Vector2(1,2)), colon_color)
	for y in [29,50]: draw_rect(Rect2(1,y,67,1), active_color)
