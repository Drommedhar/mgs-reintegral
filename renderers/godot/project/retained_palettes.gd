extends RefCounted

const BYTE_LIMIT = 64 * 1024 * 1024
const COUNT_LIMIT = 2048
var deformation_supported := false
var live_textures_supported := false
var session_id := PackedByteArray()
var entries: Dictionary = {}
var resident_bytes := 0
var received_bytes := 0
var updates := 0

func apply(payload: PackedByteArray) -> String:
	if payload.size() < 40:
		return "Truncated palette resource header"
	if session_id.size() != 16 or payload.slice(24, 40) != session_id:
		return "Palette resource belongs to a different session"
	var action := payload.decode_u32(0)
	var id := payload.decode_u32(4)
	var kind := payload.decode_u32(8)
	var previous := payload.decode_u32(12)
	var revision := payload.decode_u32(16)
	var size := payload.decode_u32(20)
	if id == 0 or kind not in [1, 2, 3, 4] or (kind == 3 and not deformation_supported) or (kind == 4 and not live_textures_supported) or size > BYTE_LIMIT or payload.size() != 40 + size:
		return "Invalid palette resource identity or length"
	var key := id * 4 + kind
	var existing: Dictionary = entries.get(key, {})
	if action == 1:
		if not existing.is_empty() or previous != 0 or revision != 1 or entries.size() >= COUNT_LIMIT:
			return "Invalid palette resource creation"
	elif action in [2, 3]:
		if existing.is_empty() or previous != existing.revision:
			return "Palette resource update references a stale revision"
		if action == 2 and (revision != previous + 1 or previous == 0xffffffff):
			return "Invalid palette resource revision"
	else:
		return "Unknown palette resource action"
	var old_size: int = existing.get("size", 0)
	if action == 3:
		if size != 0 or revision != 0:
			return "Invalid palette resource retirement"
		entries.erase(key)
		resident_bytes -= old_size
		return ""
	var stride: int = {1:4, 2:16, 3:12, 4:16}[kind]
	if size == 0 or size % stride != 0 or resident_bytes - old_size + size > BYTE_LIMIT:
		return "Palette resource exceeds format or memory limits"
	if kind == 3:
		for component in payload.slice(40).to_float32_array():
			if not is_finite(component): return "Invalid native deformation coordinate"
	if kind == 4:
		var components := payload.slice(40).to_float32_array()
		for index in components.size():
			var value := components[index]
			var limit: float = [256.0, 256.0, 65536.0, 65535.0][index % 4]
			if not is_finite(value) or value < 0 or value > limit: return "Invalid live texture descriptor"
			if index % 4 >= 2 and value != floor(value): return "Fractional live texture address"
			if index % 4 == 2 and value > 0 and (((int(value) - 1) >> 7) & 3) == 3: return "Reserved live texture format"
	entries[key] = {"revision": revision, "size": size, "data": payload.slice(40)}
	resident_bytes += size - old_size
	received_bytes += size
	updates += 1
	return ""

func resolve(id: int, kind: int, revision: int, size: int) -> PackedByteArray:
	var entry: Dictionary = entries.get(id * 4 + kind, {})
	if entry.is_empty() or entry.revision != revision or entry.size != size:
		return PackedByteArray()
	return entry.data
