extends RefCounted

var session_id := PackedByteArray()
var pending: Dictionary = {}
var current: Dictionary = {}

func apply(data: PackedByteArray, context: Dictionary) -> String:
	if data.size() < 104 or data.decode_u32(0) != 1: return "Invalid radar header"
	if data.slice(32, 48) != session_id or session_id.size() != 16: return "Radar session mismatch"
	var epoch := data.decode_u32(4)
	if epoch != context.get("epoch", -1): return "Radar epoch differs from native context"
	var contacts := data.decode_u32(8)
	var sights := data.decode_u32(12)
	var walls := data.decode_u32(16)
	if contacts > 96 or sights > 96 or walls > 4096: return "Radar record limit exceeded"
	if data.decode_u32(20) != 152 or data.decode_u32(24) != 40 or data.decode_u32(28) != 24: return "Invalid radar strides"
	if data.size() != 104 + contacts * 152 + sights * 40 + walls * 24: return "Invalid radar payload size"
	var state := {"epoch": epoch, "contacts": [], "sights": [], "walls": []}
	var fields := ["active", "mode", "tick", "x", "y", "scale", "alert_level", "recovery_counter", "console_x", "console_y", "countdown", "map_visible", "has_noise", "noise_seed"]
	for index in fields.size(): state[fields[index]] = data.decode_s32(48 + index * 4)
	state.tick = data.decode_u32(56)
	state.noise_seed = data.decode_u32(100)
	if state.active not in [0, 1] or state.mode not in [0, 1, 2, 3, 5] or state.map_visible not in [0, 1] or state.has_noise not in [0, 1]: return "Invalid radar mode or visibility"
	if absi(state.x) > 32768 or absi(state.y) > 32768 or state.scale < 0 or state.scale > 32767: return "Invalid radar placement or scale"
	if state.alert_level < 0 or state.alert_level > 256 or state.recovery_counter < -1 or state.recovery_counter > 93 or state.console_x < 0 or state.console_x > 56 or state.console_y < 0: return "Invalid radar native counters"
	if not state.active and (contacts or sights or walls or state.map_visible or state.has_noise): return "Hidden radar contains visible state"
	var offset := 104
	for index in contacts:
		var contact := {"position": point(data, offset), "kind": data.decode_u32(offset + 8), "actor_index": data.decode_u32(offset + 12), "attributes": data.decode_u32(offset + 16), "color": data.decode_u32(offset + 20), "noise": []}
		if contact.kind > 3 or contact.actor_index >= 96 or contact.attributes > 65535 or contact.color > 0xffffff: return "Invalid radar contact"
		for sample in 16: contact.noise.append(point(data, offset + 24 + sample * 8))
		state.contacts.append(contact)
		offset += 152
	for index in sights:
		var sight := {"points": PackedVector2Array(), "color": data.decode_u32(offset + 32), "fade_color": data.decode_u32(offset + 36)}
		if sight.color > 0xffffff or sight.fade_color > 0xffffff: return "Invalid radar cone colors"
		for vertex in 4: sight.points.append(point(data, offset + vertex * 8))
		state.sights.append(sight)
		offset += 40
	for index in walls:
		var wall := {"from": point(data, offset), "to": point(data, offset + 8), "kind": data.decode_u32(offset + 16), "dynamic": data.decode_u32(offset + 20)}
		if wall.kind > 2 or wall.dynamic > 1: return "Invalid radar wall"
		state.walls.append(wall)
		offset += 24
	pending = state
	return ""

static func point(data: PackedByteArray, offset: int) -> Vector2:
	return Vector2(data.decode_s32(offset), data.decode_s32(offset + 4))

func present(epoch: int) -> Dictionary:
	current = pending.duplicate(true) if pending.get("epoch", -1) == epoch else {}
	return current
