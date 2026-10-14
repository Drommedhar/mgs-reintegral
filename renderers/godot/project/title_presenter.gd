extends "res://native_ui_presenter.gd"

func _init() -> void:
	slot = "title"
	builder_script = preload("res://title_scene.gd")
	state = preload("res://title_state.gd").new()
