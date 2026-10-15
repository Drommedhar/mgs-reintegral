extends "res://native_ui_presenter.gd"

func _init() -> void:
	slot = "codec"
	builder_script = preload("res://codec_scene.gd")
	state = preload("res://codec_state.gd").new()
