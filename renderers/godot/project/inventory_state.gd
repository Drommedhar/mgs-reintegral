extends RefCounted

var session_id := PackedByteArray()
var pending: Dictionary = {}
var current: Dictionary = {}
var description := preload("res://subtitles_state.gd").new()

func decode_panels(data: PackedByteArray, count: int) -> Array[Dictionary]:
	var panels: Array[Dictionary] = []
	for index in count:
		var offset := 176 + index * 80
		var panel := {"side": data.decode_u32(offset), "id": data.decode_s32(offset + 4),
			"position": Vector2(data.decode_s32(offset + 8), data.decode_s32(offset + 12)),
			"icon": data.decode_u32(offset + 16), "flags": data.decode_u32(offset + 20),
			"quantity": data.decode_s32(offset + 24), "maximum": data.decode_s32(offset + 28),
			"level": data.decode_s32(offset + 32), "magazine": data.decode_s32(offset + 36),
			"magazine_max": data.decode_s32(offset + 40), "burst": data.decode_s32(offset + 44)}
		var name := data.slice(offset + 48, offset + 80)
		var end := name.find(0)
		if end < 0: return []
		for byte in name.slice(0, end):
			if byte < 32 or byte > 126: return []
		panel.name = name.slice(0, end).get_string_from_ascii()
		if panel.side > 1 or panel.id < -1 or panel.id > (23 if panel.side == 0 else 9): return []
		if panel.icon > 32 or panel.flags & ~255 or panel.magazine_max < 0 or panel.magazine_max > 100: return []
		if panel.id >= 0 and panel.icon == 0: return []
		if absf(panel.position.x) > 32768 or absf(panel.position.y) > 32768: return []
		if panel.magazine < 0 or panel.magazine > panel.magazine_max or panel.burst not in [0, 3]: return []
		panels.append(panel)
	return panels

func apply(data: PackedByteArray, context: Dictionary) -> String:
	if data.size() < 176 or data.decode_u32(0) != 1 or data.decode_u32(12) != 80: return "Invalid inventory schema or stride"
	var count := data.decode_u32(8)
	if count > 32 or data.size() < 176 + count * 80: return "Invalid inventory panel extent"
	if data.decode_u64(20) != 0 or data.decode_u32(28) != 0: return "Invalid inventory reserved fields"
	if session_id.size() != 16 or data.slice(32,48) != session_id: return "Inventory session mismatch"
	var epoch := data.decode_u32(4)
	if epoch != context.get("epoch", -1) or epoch != data.decode_u32(52): return "Inventory epoch differs from native context"
	var shape := data.decode_u32(16)
	if shape != 0xffffffff and shape > 2: return "Invalid PAL key state"
	var panels := decode_panels(data, count)
	if panels.size() != count: return "Invalid inventory panel"
	var text := data.slice(48,176)
	text.append_array(data.slice(176 + count * 80))
	if text.decode_u32(40) > 1: return "Invalid inventory description side"
	description.session_id = session_id
	var error: String = description.apply(text, context)
	if not error.is_empty(): return error
	pending = {"epoch": epoch, "active": count > 0 or description.pending.active,
		"panels": panels, "shape": -1 if shape == 0xffffffff else shape, "description": description.pending}
	return ""

func present(epoch: int) -> Dictionary:
	current = pending if pending.get("epoch", -1) == epoch else {}
	return current
