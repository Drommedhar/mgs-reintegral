extends RefCounted

var enabled := true
var pattern_scale := 1.0

func configure_environment() -> String:
	var mode := OS.get_environment("MGS_GODOT_DITHERING")
	if mode not in ["", "0", "1"]:
		return "MGS_GODOT_DITHERING must be 0 or 1"
	var scale := OS.get_environment("MGS_GODOT_DITHER_SCALE")
	if not scale.is_empty() and not scale.is_valid_float():
		return "MGS_GODOT_DITHER_SCALE must be a number between 0.25 and 4.0"
	pattern_scale = 1.0 if scale.is_empty() else float(scale)
	if not is_finite(pattern_scale) or pattern_scale < 0.25 or pattern_scale > 4.0:
		return "MGS_GODOT_DITHER_SCALE must be between 0.25 and 4.0"
	enabled = mode != "0"
	return ""

func adapt_fragment(source: String) -> String:
	var replacements := {
		"int(gl_FragCoord.x)": "int(gl_FragCoord.x / %.8f)" % pattern_scale,
		"int(gl_FragCoord.y)": "int(gl_FragCoord.y / %.8f)" % pattern_scale,
		"float off = ditherMatrix[dy][dx];": "float off = 0.0;",
	}
	for anchor in replacements:
		if source.count(anchor) != 1: return ""
	if pattern_scale != 1.0:
		for anchor in ["int(gl_FragCoord.x)", "int(gl_FragCoord.y)"]:
			source = source.replace(anchor, replacements[anchor])
	if not enabled:
		var anchor := "float off = ditherMatrix[dy][dx];"
		source = source.replace(anchor, replacements[anchor])
	return source
