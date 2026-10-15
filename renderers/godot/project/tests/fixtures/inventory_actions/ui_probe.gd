extends "inventory_ui.gd"

func _ready() -> void:
	add_child(preload("probe.gd").new())
