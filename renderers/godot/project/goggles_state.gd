extends RefCounted

var session_id := PackedByteArray()
var pending: Dictionary = {}
var current: Dictionary = {}

func apply(payload: PackedByteArray, context: Dictionary) -> String:
	if payload.size() != 68 or payload.decode_u32(0) != 1: return "Invalid goggles UI schema or size"
	if session_id.size() != 16 or payload.slice(52, 68) != session_id: return "Goggles UI session mismatch"
	var epoch := payload.decode_u32(4)
	if epoch != context.get("epoch", -1): return "Goggles UI epoch differs from native context"
	var mode := payload.decode_u32(8)
	var flags := payload.decode_u32(12)
	var heading := payload.decode_u32(16)
	var timer := payload.decode_u32(20)
	var layers := payload.decode_u32(24)
	if mode > 2 or flags & ~7 or heading > 4095 or layers & ~7: return "Invalid goggles UI fields"
	if bool(mode) != bool(flags & 1) or (flags & 4 and not flags & 2): return "Inconsistent goggles UI visibility"
	if mode == 0 and (flags or heading or timer or layers): return "Inactive goggles carry active UI state"
	var offsets: Array[Vector2] = []
	for layer in 3:
		var x := payload.decode_s32(28 + layer * 8)
		var y := payload.decode_s32(32 + layer * 8)
		if absi(x) > 20 or absi(y) > 20: return "Goggles sight offset exceeds native bounds"
		if not layers & (1 << layer) and (x or y): return "Hidden goggles layer carries an offset"
		offsets.append(Vector2(x, y))
	pending = {"epoch": epoch, "mode": mode, "active": bool(flags & 1), "hud": bool(flags & 2), "scan": bool(flags & 4), "heading": heading, "timer": timer, "layers": layers, "offsets": offsets}
	return ""

func present(epoch: int) -> Dictionary:
	if pending.get("epoch", -1) != epoch:
		current = {}
	else:
		current = pending.duplicate(true)
	return current
