extends SceneTree

func _initialize() -> void:
	var policy := preload("res://capture_policy.gd")
	OS.set_environment("MGS_GODOT_CAPTURE_EVERY", "100")
	OS.set_environment("MGS_GODOT_CAPTURE_FRAME", "17")
	OS.set_environment("MGS_GODOT_PERFORMANCE_RUN", "0")
	OS.unset_environment("MGS_GODOT_DIAGNOSTIC_CAPTURE")
	assert(not policy.due(100) and not policy.due(17))
	OS.set_environment("MGS_GODOT_DIAGNOSTIC_CAPTURE", "1")
	assert(policy.due(100) and policy.due(17) and not policy.due(18))
	OS.set_environment("MGS_GODOT_PERFORMANCE_RUN", "1")
	assert(not policy.enabled() and not policy.due(100) and not policy.due(17))
	print("MGS_CAPTURE_POLICY_TEST passed")
	quit()
