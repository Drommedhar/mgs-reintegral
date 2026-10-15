extends "res://native_ui_presenter.gd"

func _init() -> void:
	slot = "inventory"
	builder_script = preload("res://inventory_scene.gd")
	state = preload("res://inventory_state.gd").new()
