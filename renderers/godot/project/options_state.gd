extends RefCounted

const TextState = preload("res://subtitles_state.gd")
var session_id := PackedByteArray()
var pending: Dictionary = {}
var current: Dictionary = {}
var _texts: Dictionary = {}
var _generation := -1
var _epoch := -1
var _texture_ids: Dictionary = {}

func _init() -> void:
	var layout := preload("res://options_layout.gd")
	for name in layout.TEXTURES: _texture_ids[layout.texture_id(name)] = true

func apply(data: PackedByteArray, context: Dictionary) -> String:
	if data.size() < 104 or data.decode_u32(0) != 1: return "Invalid Options header"
	if session_id.size() != 16 or data.slice(16,32) != session_id: return "Options session mismatch"
	var epoch := data.decode_u32(4)
	if epoch != context.get("epoch", -1): return "Options epoch mismatch"
	var generation := data.decode_u32(8)
	var keys := ["active","selection","animation","vibration","test","controller_row","controller_type","reverse"]
	var next := {"epoch":epoch,"generation":generation,"revision":data.decode_u32(12),"values":[],"elements":[],"texts":{}}
	for index in keys.size(): next[keys[index]] = data.decode_u32(32 + index*4)
	if next.active > 1 or next.selection > 11 or next.animation > 53 or next.vibration > 2 or next.test > 9 or next.controller_row > 2 or next.controller_type > 2 or next.reverse > 1: return "Invalid Options state"
	for index in 8:
		var value := data.decode_u32(64+index*4)
		if value > 1: return "Invalid Options value"
		next.values.append(value)
	var count := data.decode_u32(96)
	var text_count := data.decode_u32(100)
	if count != (57 if next.active else 0) or text_count > 31 or (not next.active and text_count) or (next.active and generation == 0): return "Invalid Options counts"
	var offset := 104
	for index in count:
		if offset + 32 > data.size(): return "Truncated Options element"
		var element := {"texture":data.decode_u32(offset),"position":Vector2(data.decode_s32(offset+4),data.decode_s32(offset+8)),
			"size":Vector2(data.decode_s32(offset+12),data.decode_s32(offset+16)),"rgb":data.decode_u32(offset+20),"layer":data.decode_u32(offset+24),"blend":data.decode_u32(offset+28)}
		if not _texture_ids.has(element.texture) or element.rgb > 0xffffff or element.layer > 3 or element.blend > 4 or element.size.x < 0 or element.size.y < 0 or element.size.x > 1024 or element.size.y > 512 or element.position.abs().x > 2048 or element.position.abs().y > 2048: return "Invalid Options element"
		next.elements.append(element)
		offset += 32
	return apply_texts(data, offset, text_count, context, next, 31)

func apply_texts(data: PackedByteArray, offset: int, text_count: int, context: Dictionary, next: Dictionary, limit: int) -> String:
	var epoch: int = next.epoch
	var generation: int = next.generation
	var retained: Dictionary = _texts.duplicate() if epoch == _epoch and generation == _generation else {}
	for index in text_count:
		if offset + 132 > data.size(): return "Truncated Menu text"
		var identity := data.decode_u32(offset)
		var glyphs := data.decode_u32(offset+88)
		if identity >= limit or next.texts.has(identity) or glyphs > 4096 or offset+132+glyphs*80 > data.size(): return "Invalid Menu text extent"
		var text := TextState.new()
		text.session_id = session_id
		text._layout = retained.get(identity,{})
		var error: String = text.apply(data.slice(offset+4,offset+132+glyphs*80),context)
		if not error.is_empty(): return error
		if not text.pending.active: return "Menu text must be active"
		retained[identity] = text._layout
		next.texts[identity] = text.pending
		offset += 132+glyphs*80
	if offset != data.size(): return "Unexpected Menu trailing data"
	_texts = retained
	_epoch = epoch
	_generation = generation
	pending = next
	return ""

func present(epoch: int) -> Dictionary:
	current = pending if pending.get("epoch",-1) == epoch else {}
	return current
