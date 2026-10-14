extends RefCounted

const IMAGE_BYTES = 6656
const FIELDS = ["active", "incoming", "mode", "frequency", "action", "signal", "fade", "scanline",
	"wait_mark", "exit_hint", "memory", "memory_top", "memory_selected", "memory_count", "memory_animation", "reserved"]
var session_id := PackedByteArray()
var pending: Dictionary = {}
var current: Dictionary = {}
var text := preload("res://subtitles_state.gd").new()
var _images: Array[PackedByteArray] = []
var _epoch := -1

func apply(data: PackedByteArray, context: Dictionary) -> String:
	if data.size() < 320 or data.decode_u32(0) != 1 or data.decode_u32(12) != 0: return "Invalid Codec header"
	if session_id.size() != 16 or data.slice(16,32) != session_id: return "Codec session mismatch"
	var epoch := data.decode_u32(4)
	if epoch != context.get("epoch", -1) or data.decode_u32(196) != epoch: return "Codec epoch mismatch"
	var mask := data.decode_u32(8)
	if mask & ~15: return "Invalid Codec portrait mask"
	var count := data.decode_u32(276)
	var images_size := 0
	for index in 4:
		if mask & (1 << index): images_size += IMAGE_BYTES
	if count > 4096 or data.size() != 320 + count * 80 + images_size: return "Invalid Codec payload extent"
	var next := {"epoch":epoch}
	for index in FIELDS.size(): next[FIELDS[index]] = data.decode_u32(32 + index * 4)
	for key in ["active", "incoming", "wait_mark", "exit_hint", "memory"]:
		if next[key] > 1: return "Invalid Codec flags"
	if next.mode > 20 or next.frequency > 14199 or next.action & ~15 or next.signal > 9 or next.fade > 255 or next.scanline > 127: return "Invalid Codec controls"
	if next.memory_count > 32 or next.memory_top > next.memory_count or next.memory_selected > next.memory_count or next.memory_animation > 5 or next.reserved != 0: return "Invalid Codec memory state"
	var faces: Array[Dictionary] = []
	for index in 2:
		var at := 96 + index * 32
		var face := {"position":Vector2(data.decode_s32(at),data.decode_s32(at+4)),
			"size":Vector2(data.decode_s32(at+8),data.decode_s32(at+12)), "previous_weight":data.decode_u32(at+16),
			"bracket":data.decode_s32(at+20), "scanline":data.decode_s32(at+24), "visible":data.decode_u32(at+28)}
		if face.visible > 1 or face.previous_weight > 128 or face.bracket < 0 or face.bracket > 56 or face.scanline < 0 or face.scanline > 109: return "Invalid Codec portrait state"
		if face.visible and (face.size.x != 52 or face.size.y < 1 or face.size.y > 89 or face.position.x != (31 if index == 0 else 237) or face.position.y < 30 or face.position.y > 74): return "Invalid Codec portrait bounds"
		faces.append(face)
	var contacts := PackedInt32Array()
	for index in 8:
		var frequency := data.decode_u32(160 + index * 4)
		if frequency != 0 and (frequency < 14000 or frequency > 14199): return "Invalid Codec contact frequency"
		contacts.append(frequency)
	if _epoch != epoch and mask != 15: return "Codec epoch requires all portrait resources"
	text.session_id = session_id
	var error: String = text.apply(data.slice(192, 320 + count * 80), context)
	if not error.is_empty(): return error
	var images: Array[PackedByteArray] = []
	if _epoch == epoch:
		images.assign(_images)
	else:
		images.resize(4)
		images.fill(PackedByteArray())
	var offset := 320 + count * 80
	for index in 4:
		if mask & (1 << index):
			images[index] = data.slice(offset, offset + IMAGE_BYTES)
			offset += IMAGE_BYTES
	next.faces = faces
	next.contacts = contacts
	next.images = images
	next.message = text.pending
	_images = images
	_epoch = epoch
	pending = next
	return ""

func present(epoch: int) -> Dictionary:
	current = pending if pending.get("epoch", -1) == epoch else {}
	return current
