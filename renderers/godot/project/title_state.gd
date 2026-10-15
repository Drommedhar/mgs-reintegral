extends "res://options_state.gd"

func _init() -> void:
	_texture_ids.clear()
	var layout := preload("res://title_layout.gd")
	for name in layout.TEXTURES: _texture_ids[layout.texture_id(name)] = true

func apply(data: PackedByteArray, context: Dictionary) -> String:
	if data.size() < 72 or data.decode_u32(0) != 1: return "Invalid title header"
	if session_id.size() != 16 or data.slice(16,32) != session_id: return "Title session mismatch"
	var epoch := data.decode_u32(4)
	if epoch != context.get("epoch",-1): return "Title epoch mismatch"
	var next := {"epoch":epoch,"generation":data.decode_u32(8),"revision":data.decode_u32(12),"elements":[],"texts":{}}
	var keys := ["active","mode","selection","difficulty","extreme","storage_choice","storage_a","storage_b"]
	for index in keys.size(): next[keys[index]] = data.decode_u32(32+index*4)
	if next.active>1 or next.mode>21 or next.selection>5 or next.difficulty>4 or next.extreme>1 or next.storage_choice>1: return "Invalid title state"
	var count := data.decode_u32(64)
	var text_count := data.decode_u32(68)
	if count != (55 if next.active else 0) or text_count>24 or (not next.active and text_count) or (next.active and next.generation==0): return "Invalid title counts"
	var offset := 72
	for index in count:
		if offset+52 > data.size(): return "Truncated title element"
		var element := {"texture":data.decode_u32(offset),"position":Vector2(data.decode_s32(offset+4),data.decode_s32(offset+8)),
			"size":Vector2(data.decode_s32(offset+12),data.decode_s32(offset+16)),
			"source":Rect2(data.decode_s32(offset+20),data.decode_s32(offset+24),data.decode_s32(offset+28),data.decode_s32(offset+32)),
			"top_rgb":data.decode_u32(offset+36),"bottom_rgb":data.decode_u32(offset+40),"layer":data.decode_u32(offset+44),"blend":data.decode_u32(offset+48)}
		if not _texture_ids.has(element.texture) or element.top_rgb>0xffffff or element.bottom_rgb>0xffffff or element.layer>7 or element.blend>4: return "Invalid title artwork"
		if element.size.abs().x>2048 or element.size.abs().y>2048 or element.position.abs().x>4096 or element.position.abs().y>4096: return "Invalid title rectangle"
		var source: Rect2 = element.source
		if source.position.x<0 or source.position.y<0 or source.position.x>255 or source.position.y>255 or source.size.x<1 or source.size.y<1 or source.size.x>256 or source.size.y>256: return "Invalid title crop"
		next.elements.append(element)
		offset += 52
	return apply_texts(data, offset, text_count, context, next, 24)
