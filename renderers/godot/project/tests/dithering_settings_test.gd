extends SceneTree

const Dithering = preload("res://dithering.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	var settings := Dithering.new()
	OS.unset_environment("MGS_GODOT_DITHERING")
	OS.unset_environment("MGS_GODOT_DITHER_SCALE")
	check(settings.configure_environment().is_empty() and settings.enabled and settings.pattern_scale == 1.0,
		"Default environment must preserve original dithering")
	var original := FileAccess.get_file_as_string("res://.generated/psx.frag.glsl")
	check(not original.is_empty() and settings.adapt_fragment(original) == original,
		"Default settings must preserve the complete primitive shader")
	check(settings.adapt_fragment("#version 450\nvoid main() {}\n").is_empty(),
		"Changed shader layout must fail explicitly")
	check(settings.adapt_fragment(original + original).is_empty(),
		"Ambiguous shader anchors must fail explicitly")
	for scale in ["0.25", "0.5", "1.0", "1.3", "1.4", "4.0"]:
		OS.set_environment("MGS_GODOT_DITHER_SCALE", scale)
		check(settings.configure_environment().is_empty() and settings.pattern_scale == float(scale),
			"Fractional scale rejected: " + scale)
	for scale in ["0", "-1", "0.24", "4.01", "NaN", "inf", "1e999", "1,3", "1.3x"]:
		OS.set_environment("MGS_GODOT_DITHER_SCALE", scale)
		check(not settings.configure_environment().is_empty(), "Invalid scale accepted: " + scale)
	OS.unset_environment("MGS_GODOT_DITHER_SCALE")
	OS.set_environment("MGS_GODOT_DITHERING", "0")
	check(settings.configure_environment().is_empty() and not settings.enabled, "Explicit dithering opt-out ignored")
	OS.set_environment("MGS_GODOT_DITHERING", "false")
	check(not settings.configure_environment().is_empty(), "Invalid toggle must fail explicitly")
	if failures == 0: print("PASS: dithering settings validation and strict shader adaptation")
	quit(0 if failures == 0 else 1)
