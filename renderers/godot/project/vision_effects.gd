extends RefCounted

const NightVision = preload("res://night_vision_effect.gd")
const ThermalVision = preload("res://thermal_vision_effect.gd")
var world: CompositorEffect
var background: CompositorEffect
var thermal_world: CompositorEffect
var thermal_background: CompositorEffect
var thermal_enabled := false
var mode := 0

func initialize(definitions: Dictionary, on_error: Callable) -> String:
	for kind in ["night_vision", "thermal_vision"]:
		var original: Resource = NightVision.new() if kind == "night_vision" else ThermalVision.new()
		if definitions.has(kind): original = load(definitions[kind].effect)
		if not original is CompositorEffect: return kind + " requires a CompositorEffect resource"
		var methods := ["validate", "set_native_state", "prepare", "release"]
		if kind == "thermal_vision": methods.append("set_heat_capture")
		for method in methods:
			if not original.has_method(method): return kind + " compositor is missing: " + method
		if not original.has_signal("failed"): return kind + " compositor requires a failed signal"
		var result = original.call("validate")
		if not result is String: return "Vision compositor validation must return a String"
		if not result.is_empty(): return result
		var pair: Array[CompositorEffect] = [original.duplicate(true), original.duplicate(true)]
		if kind == "night_vision":
			world = pair[0]
			background = pair[1]
		else:
			thermal_world = pair[0]
			thermal_background = pair[1]
	for effect in [world, background, thermal_world, thermal_background]:
		effect.connect("failed", on_error)
		effect.call("set_native_state", 0, 0)
		RenderingServer.call_on_render_thread(Callable(effect, "prepare"))
	return ""

func update(context: Dictionary) -> bool:
	var next: int = context.get("vision_mode", 0)
	var changed := mode != next
	mode = next
	for effect in [world, background]:
		if effect != null: effect.call("set_native_state", mode, context.get("actor_loop_tick", 0))
	for effect in [thermal_world, thermal_background]:
		if effect != null: effect.call("set_native_state", mode if thermal_enabled else 0, context.get("actor_loop_tick", 0))
	if changed: print("MGS_VISION mode=%d" % mode)
	return changed

func release() -> void:
	for effect in [world, background, thermal_world, thermal_background]:
		if effect != null: effect.call("release")
