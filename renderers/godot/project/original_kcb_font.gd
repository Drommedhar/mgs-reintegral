@tool
extends RefCounted

const GLYPH_BASE := 0xF0000
const DASH_CODE := 0xF4000

static func valid_document(value: Dictionary) -> bool:
	var count = value.get("bank_length")
	if not count is float or not is_finite(count) or count != floor(count) or count < 1 or count >= 4096: return false
	if value.get("font_size") != 12 or value.get("height") != 12 or value.get("line_height") != 18: return false
	if not value.get("glyphs") is Dictionary or value.glyphs.size() != 97 + int(count): return false
	return value.get("size") == [640.0, float(ceili((97 + count) / 32.0) * 16)]

static func valid_glyphs(value: Dictionary) -> bool:
	var codes: Array[int] = []
	for code in range(32, 128): codes.append(code)
	for index in int(value.bank_length): codes.append(GLYPH_BASE + index + 1)
	codes.append(DASH_CODE)
	for index in codes.size():
		var entry = value.glyphs.get(str(codes[index]))
		if not entry is Dictionary: return false
		var width = entry.get("advance")
		var offset_y = entry.get("offset_y")
		if not width is float or not is_finite(width) or width != floor(width): return false
		if not offset_y is float or offset_y not in [0.0, 1.0, 2.0] or entry.get("offset") != 0: return false
		if codes[index] == DASH_CODE:
			if width != 18 or offset_y != 0: return false
		elif codes[index] > GLYPH_BASE:
			if width != 12 or offset_y != 1: return false
		elif width < 1 or width > 12: return false
		if entry.get("rect") != [float(index % 32 * 20 + 1), float(index / 32 * 16 + 1), width, 12.0]: return false
	return true
