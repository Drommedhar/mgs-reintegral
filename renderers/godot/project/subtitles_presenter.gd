extends "res://native_ui_presenter.gd"

func _init() -> void:
	slot = "subtitles"
	builder_script = preload("res://subtitles_scene.gd")
	state = preload("res://subtitles_state.gd").new()
