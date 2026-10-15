extends "res://native_ui_presenter.gd"

func _init() -> void:
	slot = "save_load"
	builder_script = preload("res://save_scene.gd")
	state = preload("res://save_state.gd").new()
