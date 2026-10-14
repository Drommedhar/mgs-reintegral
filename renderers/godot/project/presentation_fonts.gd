@tool
extends RefCounted

const SCALE := 8
static var block_atlas: Image
static var dialogue: FontFile
static var dialogue_ink: Dictionary = {}

static func dialogue_bounds(code: int) -> Rect2:
	if dialogue_ink.has(code): return dialogue_ink[code]
	var server := TextServerManager.get_primary_interface()
	var rid := dialogue_font().get_rids()[0]
	var index := server.font_get_glyph_index(rid, 96, code, 0)
	var points: PackedVector3Array = server.font_get_glyph_contours(rid, 96, index).get("points", PackedVector3Array())
	var bounds := Rect2()
	for point_index in points.size():
		var point := points[point_index]
		var position := Vector2(point.x, point.y)
		bounds = Rect2(position, Vector2.ZERO) if point_index == 0 else bounds.expand(position)
	dialogue_ink[code] = bounds
	return bounds

static func enabled() -> bool:
	return OS.get_environment("MGS_GODOT_PIXEL_FONTS") != "1"

static func dialogue_font() -> FontFile:
	if not enabled(): return null
	if dialogue == null:
		dialogue = FontFile.new()
		var error := dialogue.load_dynamic_font("res://texgyreheros-regular.otf")
		if error != OK:
			push_error("Cannot load presentation font: " + error_string(error))
			dialogue = null
			return null
		dialogue.multichannel_signed_distance_field = true
		dialogue.allow_system_fallback = false
	return dialogue

static func block_image(document: Dictionary, original: Image) -> Image:
	if block_atlas == null:
		block_atlas = Image.new()
		var error := block_atlas.load_png_from_buffer(FileAccess.get_file_as_bytes("res://interface-font.png"))
		if error != OK:
			push_error("Cannot load presentation font atlas: " + error_string(error))
			block_atlas = null
			return null
	var result := original.duplicate() as Image
	result.resize(original.get_width() * SCALE, original.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	for character in document.glyphs:
		var index := int(character) - 32
		if index < 0 or index >= 95: continue
		var glyph: Dictionary = document.glyphs[character]
		var rect := Rect2i(glyph.rect[0], glyph.rect[1], glyph.rect[2], glyph.rect[3])
		if not rect.has_area(): continue
		var ink := original.get_region(rect).get_used_rect()
		if not ink.has_area(): continue
		var cell := block_atlas.get_region(Rect2i((index % 16) * 128, (index / 16) * 112, 64, 48))
		var coverage := cell.get_used_rect()
		if not coverage.has_area(): continue
		var replacement := cell.get_region(coverage)
		replacement.resize(ink.size.x * SCALE, ink.size.y * SCALE, Image.INTERPOLATE_LANCZOS)
		result.fill_rect(Rect2i(rect.position * SCALE, rect.size * SCALE), Color(1,1,1,0))
		result.blit_rect(replacement, Rect2i(Vector2i.ZERO, replacement.get_size()), (rect.position + ink.position) * SCALE)
	return result
