extends "res://native_ui_presenter.gd"

func _init() -> void:
	slot = "options"
	builder_script = preload("res://options_scene.gd")
	state = preload("res://options_state.gd").new()
