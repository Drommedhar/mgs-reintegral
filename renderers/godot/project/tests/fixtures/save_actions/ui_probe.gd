extends "res://save_ui.gd"

func _ready() -> void:
	var probe := preload("res://tests/fixtures/save_actions/probe.gd").new()
	add_child(probe)
