extends MeshInstance3D

func _ready() -> void:
	get_parent().state_changed.connect(update_indicator)
	if not get_parent().native_state.is_empty(): update_indicator(get_parent().native_state)

func update_indicator(state: Dictionary) -> void:
	var stopped: bool = state.phase in [0, 2]
	material_override.emission = Color(0.15, 0.8, 0.25) if stopped else Color(1.0, 0.35, 0.03)
