extends "res://native_ui_presenter.gd"

func _init() -> void:
	slot = "bars"
	builder_script = preload("res://bars_scene.gd")
	state = preload("res://bars_state.gd").new()
