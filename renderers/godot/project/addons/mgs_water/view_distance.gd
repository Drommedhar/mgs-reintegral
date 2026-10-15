extends Node

@export_range(250.0, 10000.0) var distance := 1500.0
var api: Node

func _ready() -> void:
	api = get_tree().get_first_node_in_group("mgs_visual_api_v1")
	if api != null:
		var error: String = api.set_view_distance(self, distance)
		if not error.is_empty(): push_error(error)

func _exit_tree() -> void:
	if is_instance_valid(api) and api.scene != null: api.set_view_distance(self, 0)
