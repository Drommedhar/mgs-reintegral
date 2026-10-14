@tool
extends TextureRect

var _source := PackedByteArray()

func apply_image(source: PackedByteArray) -> void:
	if texture != null and not texture.has_meta("mgs_retail_derived"): return
	if source == _source: return
	_source = source
	var pixels := PackedByteArray()
	pixels.resize(52 * 89 * 3)
	for y in 89:
		for x in 52:
			var color := source.decode_u16(6144 + source[y * 64 + x] * 2)
			var offset := (y * 52 + x) * 3
			pixels[offset] = (color & 31) * 255 / 31
			pixels[offset+1] = ((color >> 5) & 31) * 255 / 31
			pixels[offset+2] = ((color >> 10) & 31) * 255 / 31
	var image := Image.create_from_data(52,89,false,Image.FORMAT_RGB8,pixels)
	if texture == null:
		texture = ImageTexture.create_from_image(image)
		texture.set_meta("mgs_retail_derived", true)
	else:
		(texture as ImageTexture).update(image)

func detach_originals() -> void:
	if texture != null and texture.has_meta("mgs_retail_derived"): texture = null
	_source = PackedByteArray()
