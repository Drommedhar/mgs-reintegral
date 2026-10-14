extends "res://native_ui_presenter.gd"

func _init() -> void:
	slot = "radar"
	builder_script = preload("res://radar_scene.gd")
	state = preload("res://radar_state.gd").new()
