extends "res://native_ui_presenter.gd"

func _init() -> void:
	slot = "goggles"
	builder_script = preload("res://goggles_scene.gd")
	state = preload("res://goggles_state.gd").new()
