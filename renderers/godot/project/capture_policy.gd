extends RefCounted

static func enabled() -> bool:
	return OS.get_environment("MGS_GODOT_DIAGNOSTIC_CAPTURE") == "1" and OS.get_environment("MGS_GODOT_PERFORMANCE_RUN") != "1"

static func due(frame: int) -> bool:
	if not enabled(): return false
	var interval := int(OS.get_environment("MGS_GODOT_CAPTURE_EVERY"))
	return frame == int(OS.get_environment("MGS_GODOT_CAPTURE_FRAME")) or (interval > 0 and frame % interval == 0)
