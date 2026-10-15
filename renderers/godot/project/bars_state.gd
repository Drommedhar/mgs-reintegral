extends RefCounted

var session_id := PackedByteArray()
var pending: Dictionary = {}
var current: Dictionary = {}

func apply(payload: PackedByteArray, context: Dictionary) -> String:
	if payload.size() < 32 or payload.decode_u32(0) != 1 or payload.decode_u32(12) != 72:
		return "Invalid status bars schema or stride"
	var count := payload.decode_u32(8)
	if count > 16 or payload.size() != 32 + count * 72: return "Invalid status bars size"
	if session_id.size() != 16 or payload.slice(16, 32) != session_id: return "Status bars session mismatch"
	var epoch := payload.decode_u32(4)
	if epoch != context.get("epoch", -1): return "Status bars epoch differs from native context"
	var bars: Array[Dictionary] = []
	for index in count:
		var offset := 32 + index * 72
		var bar := {"position": Vector2(payload.decode_s32(offset), payload.decode_s32(offset + 4)),
			"rest": payload.decode_s32(offset + 8), "value": payload.decode_s32(offset + 12),
			"maximum": payload.decode_s32(offset + 16), "height": payload.decode_s32(offset + 20),
			"kind": payload.decode_u32(offset + 24), "damage": payload.decode_u32(offset + 28),
			"left": payload.decode_u32(offset + 32), "right": payload.decode_u32(offset + 36)}
		var name := payload.slice(offset + 40, offset + 72)
		var end := name.find(0)
		if end < 0: return "Unterminated status bar name"
		for character in name.slice(0, end):
			if character < 32 or character > 126: return "Invalid status bar name"
		bar.name = name.slice(0, end).get_string_from_ascii()
		if bar.kind > 2 or bar.damage > 1 or bar.left > 0xffffff or bar.right > 0xffffff:
			return "Invalid status bar kind, flags or colors"
		if bar.maximum < 0 or bar.maximum > 65535 or bar.height < 0 or bar.height > 5:
			return "Invalid status bar dimensions"
		bars.append(bar)
	pending = {"epoch": epoch, "active": not bars.is_empty(), "bars": bars}
	return ""

func present(epoch: int) -> Dictionary:
	current = pending.duplicate(true) if pending.get("epoch", -1) == epoch else {}
	return current
