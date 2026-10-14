extends RefCounted

var session_id := PackedByteArray()
var pending: Dictionary = {}
var current: Dictionary = {}
var _layout: Dictionary = {}

func decode_layout(payload: PackedByteArray) -> Dictionary:
	var width := payload.decode_u32(76)
	var height := payload.decode_u32(80)
	if width < 1 or width > 256 or height < 1 or height > 128: return {}
	var glyphs: Array[Dictionary] = []
	for index in payload.decode_u32(84):
		var offset := 128 + index * 80
		var glyph := {"kind": payload.decode_u32(offset), "code": payload.decode_u32(offset + 4),
			"position": Vector2i(payload.decode_s32(offset + 8), payload.decode_s32(offset + 12)),
			"size": Vector2i(payload.decode_u32(offset + 16), payload.decode_u32(offset + 20)),
			"color": payload.decode_u32(offset + 24)}
		var length := payload.decode_u32(offset + 28)
		if glyph.kind < 1 or glyph.kind > 6 or glyph.color > 3: return {}
		if glyph.size.x < 1 or glyph.size.x > 20 or glyph.size.y < 1 or glyph.size.y > 12: return {}
		if glyph.position.x < -20 or glyph.position.y < -12 or glyph.position.x > 256 or glyph.position.y > 128: return {}
		match glyph.kind:
			1:
				if glyph.size.x > 12 or glyph.size.y != 12 or length != glyph.size.x * 3 or glyph.code < 32 or glyph.code > 254: return {}
			2:
				if glyph.size != Vector2i(12, 12) or length != 36 or glyph.code > 16383 or (glyph.code & 4095) == 0: return {}
			3:
				if glyph.size.x > 6 or glyph.size.y != 6 or length != 9 or glyph.code < 1 or glyph.code > 128: return {}
			4:
				if glyph.code > 1 or glyph.size != Vector2i(18 + glyph.code * 2, 1) or length != 0: return {}
			5:
				if glyph.size != Vector2i(2, 2) or length != 0: return {}
			6:
				if glyph.size != Vector2i(12, 12) or length != 0: return {}
		glyph.source = payload.slice(offset + 32, offset + 32 + length)
		glyphs.append(glyph)
	var palette := PackedInt32Array()
	for index in 16: palette.append(payload.decode_u16(96 + index * 2))
	return {"revision": payload.decode_u32(8), "epoch": payload.decode_u32(4),
		"size": Vector2i(width, height), "palette": palette, "glyphs": glyphs}

func apply(payload: PackedByteArray, context: Dictionary) -> String:
	if payload.size() < 128 or payload.decode_u32(0) != 1 or payload.decode_u32(88) != 80 or payload.decode_u32(92) != 0:
		return "Invalid subtitles schema or stride"
	var count := payload.decode_u32(84)
	if count > 4096 or payload.size() != 128 + count * 80: return "Invalid subtitles size"
	if session_id.size() != 16 or payload.slice(16, 32) != session_id: return "Subtitles session mismatch"
	var epoch := payload.decode_u32(4)
	if epoch != context.get("epoch", -1): return "Subtitles epoch differs from native context"
	var revision := payload.decode_u32(8)
	var has_layout := payload.decode_u32(12)
	var active := payload.decode_u32(32)
	var visible := payload.decode_u32(36)
	var kind := payload.decode_u32(40)
	if has_layout > 1 or active > 1 or visible > active or kind > 2: return "Invalid subtitle flags"
	var next_layout: Dictionary = _layout if _layout.get("epoch", -1) == epoch else {}
	if has_layout:
		if not active or revision == 0: return "Subtitle layout requires an active page"
		next_layout = decode_layout(payload)
		if next_layout.is_empty(): return "Invalid subtitle glyph layout"
	elif count != 0 or payload.decode_u32(76) != 0 or payload.decode_u32(80) != 0:
		return "Subtitle frame without layout contains glyph data"
	if active and (revision == 0 or next_layout.get("revision", 0) != revision): return "Subtitle page is not defined"
	var extent := Vector2i(payload.decode_s32(56), payload.decode_s32(60))
	if extent.x < 0 or extent.x > 256 or extent.y < 0 or extent.y > 128: return "Invalid subtitle extent"
	pending = {"epoch": epoch, "active": active == 1, "visible": visible == 1, "kind": kind,
		"timer": payload.decode_s32(44), "position": Vector2(payload.decode_s32(48), payload.decode_s32(52)),
		"size": extent, "text_width": payload.decode_s32(64), "character_spacing": payload.decode_s32(68),
		"line_spacing": payload.decode_s32(72), "layout": next_layout if active else {}}
	_layout = next_layout
	return ""

func present(epoch: int) -> Dictionary:
	current = pending if pending.get("epoch", -1) == epoch else {}
	return current
