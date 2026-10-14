@tool
extends RefCounted

const BASE := 0xF0000
const CELL := Vector2i(22, 14)

static func palette_color(value: int) -> Color:
	return Color8((value & 31) * 255 / 31, ((value >> 5) & 31) * 255 / 31, ((value >> 10) & 31) * 255 / 31, 0 if value == 0 else 255)

static func sample(glyph: Dictionary, x: int, y: int) -> int:
	if glyph.kind == 6: return glyph.color << 2
	if glyph.kind in [4, 5]: return (glyph.color << 2) | 3
	var pitch: int = 6 if glyph.kind == 3 else glyph.size.x
	var index := y * pitch + x
	return (glyph.color << 2) | ((glyph.source[index / 4] >> (6 - (index % 4) * 2)) & 3)

static func ink_bounds(glyph: Dictionary) -> Rect2:
	var bounds := Rect2()
	for y in glyph.size.y:
		for x in glyph.size.x:
			if (sample(glyph, x, y) & 3) == 0: continue
			var pixel := Rect2(x, y, 1, 1)
			bounds = bounds.merge(pixel) if bounds.has_area() else pixel
	return bounds

static func cells(layout: Dictionary) -> Array[PackedByteArray]:
	var output: Array[PackedByteArray] = []
	var owners := {}
	var values := {}
	for glyph in layout.glyphs:
		var pixels := PackedByteArray()
		pixels.resize(glyph.size.x * glyph.size.y)
		pixels.fill(255)
		output.append(pixels)
		for y in glyph.size.y:
			for x in glyph.size.x:
				if glyph.kind == 4 and glyph.code == 1 and x == 1: continue
				var point: Vector2i = glyph.position + Vector2i(x, y)
				if point.x < 0 or point.y < 0 or point.x >= layout.size.x or point.y >= layout.size.y: continue
				var value := sample(glyph, x, y)
				if glyph.kind != 6: value |= values.get(point, 0)
				if owners.has(point):
					var previous: Vector2i = owners[point]
					output[previous.x][previous.y] = 255
				var index: int = y * glyph.size.x + x
				output[-1][index] = value
				values[point] = value
				owners[point] = Vector2i(output.size() - 1, index)
	return output

static func create(layout: Dictionary) -> FontFile:
	var font := FontFile.new()
	font.set_meta("mgs_retail_derived", true)
	font.allow_system_fallback = false
	font.fixed_size = 12
	font.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_ENABLED
	font.modulate_color_glyphs = true
	font.set_cache_ascent(0, 12, 12)
	font.set_cache_descent(0, 12, 0)
	var image := Image.create(32 * CELL.x, maxi(1, ceili(layout.glyphs.size() / 32.0)) * CELL.y, false, Image.FORMAT_RGBA8)
	var pixels := cells(layout)
	for index in layout.glyphs.size():
		var glyph: Dictionary = layout.glyphs[index]
		var origin := Vector2i(index % 32, index / 32) * CELL + Vector2i.ONE
		for y in glyph.size.y:
			for x in glyph.size.x:
				var value: int = pixels[index][y * glyph.size.x + x]
				if value != 255: image.set_pixelv(origin + Vector2i(x, y), palette_color(layout.palette[value]))
		font.set_glyph_advance(0, 12, BASE + index, Vector2(glyph.size.x, 0))
		font.set_glyph_offset(0, Vector2i(12, 0), BASE + index, Vector2(0, -12))
		font.set_glyph_size(0, Vector2i(12, 0), BASE + index, glyph.size)
		font.set_glyph_uv_rect(0, Vector2i(12, 0), BASE + index, Rect2(origin, glyph.size))
		font.set_glyph_texture_idx(0, Vector2i(12, 0), BASE + index, 0)
	font.set_texture_image(0, Vector2i(12, 0), 0, image)
	return font
