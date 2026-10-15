@tool
extends Control

@export var full_color := Color.WHITE
@export var burst_color := Color(1,0.25,0.25)
@export var empty_color := Color.WHITE
@export var spacing := 3.0
var art: RefCounted
var state: Dictionary = {}

func _draw() -> void:
	if art == null: return
	for index in state.get("magazine_max", 0):
		var full: bool = index < state.magazine
		var tint: Color = burst_color if full and index < state.burst else full_color if full else empty_color
		draw_texture(art.magazine[0 if full else 1], Vector2(-spacing * (index + 1),0), tint)
