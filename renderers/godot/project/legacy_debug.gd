extends TextureRect

var _text := ""
var _font := PackedByteArray()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	visible = false

func set_text(value: String) -> void:
	visible = not value.is_empty()
	if value == _text: return
	_text = value
	if value.is_empty(): return
	if _font.is_empty():
		_font = FileAccess.get_file_as_bytes("res://.generated/legacy-debug-font.bin")
		if _font.size() != 1520:
			push_error("Legacy debug font is missing; run tools/prepare-godot.ps1")
			return
	var image := Image.create(328, 48, false, Image.FORMAT_RGBA8)
	image.fill(Color8(12, 18, 24))
	var lines := value.split("\n")
	for line in mini(lines.size(), 4):
		for column in mini(lines[line].length(), 41):
			_draw_glyph(image, lines[line].unicode_at(column), Vector2i(4 + column * 8, 5 + line * 10))
	var atlas := AtlasTexture.new()
	atlas.atlas = ImageTexture.create_from_image(image)
	atlas.region = Rect2(0, 0, 328, mini(lines.size() * 10 + 8, 48))
	texture = atlas
	fit(get_viewport_rect().size)

func _draw_glyph(image: Image, code: int, origin: Vector2i) -> void:
	if code <= 32 or (code >= 127 and code <= 160): return
	var glyph := 189 if code >= 190 else code - (33 if code < 127 else 67)
	for row in 8:
		for column in mini(8, 328 - origin.x):
			if _font[glyph * 8 + row] & (1 << column):
				image.set_pixel(origin.x + column, origin.y + row, Color8(230, 245, 240))

func fit(extent: Vector2i) -> void:
	if texture == null: return
	var factor := 2 if extent.y >= 960 and extent.x >= 672 else 1
	size = Vector2(mini(328 * factor, extent.x), mini(int(texture.region.size.y) * factor, extent.y))
	position = Vector2(extent.x - size.x - mini(12, extent.x - int(size.x)), mini(12, extent.y - int(size.y)))
