@tool
extends Control

const GlyphFont = preload("subtitles_font.gd")
const PresentationFonts = preload("presentation_fonts.gd")
@export var font_override: Font:
	set(value):
		font_override = value
		queue_redraw()
@export_range(1, 128) var font_size := 12:
	set(value):
		font_size = value
		queue_redraw()
@export var font_color := Color.WHITE:
	set(value):
		font_color = value
		queue_redraw()
@export var outline_color := Color.BLACK:
	set(value):
		outline_color = value
		queue_redraw()
@export_range(0, 8) var outline_size := 1:
	set(value):
		outline_size = value
		queue_redraw()
var preview_font: Font
var presentation_font: Font
var preview_text := "Snake, do you read me?"
var _font: FontFile
var _layout: Dictionary = {}
var _point := Vector2.ZERO
var _active := false
var _ink: Array[Rect2] = []

func apply_native_state(state: Dictionary) -> void:
	var next: Dictionary = state.get("layout", {})
	if next != _layout:
		_layout = next
		_font = null if next.is_empty() else GlyphFont.create(next)
		_ink.clear()
		for glyph in next.get("glyphs", []): _ink.append(GlyphFont.ink_bounds(glyph))
	_point = state.get("position", Vector2.ZERO)
	_active = state.get("active", false) and state.get("visible", false)
	queue_redraw()

func detach_originals() -> void:
	_font = null
	preview_font = null
	presentation_font = null
	_layout = {}
	_ink.clear()
	_active = false
	queue_redraw()

func bind_presentation_font(font: Font) -> void:
	presentation_font = font
	queue_redraw()

func _draw() -> void:
	if _layout.is_empty():
		if preview_font != null:
			var font: Font = font_override if font_override != null else preview_font
			var point := Vector2(160 - font.get_string_size(preview_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x / 2, 212)
			draw_string_outline(font, point, preview_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline_size, outline_color)
			draw_string(font, point, preview_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, font_color)
		return
	if not _active: return
	var offsets := [Vector2(-1, 0), Vector2(1, 0), Vector2(0, 1), Vector2(0, -1)]
	if outline_size:
		for offset in offsets: draw_glyphs(offset * outline_size, outline_color, false)
	draw_glyphs(Vector2.ZERO, font_color)

func draw_glyphs(offset: Vector2, tint: Color, foreground := true) -> void:
	var replacement: Font = font_override if font_override != null else presentation_font
	for index in _layout.glyphs.size():
		var glyph: Dictionary = _layout.glyphs[index]
		var custom: bool = replacement != null and glyph.kind == 1 and glyph.code < 128 and replacement.has_char(glyph.code)
		var font: Font = replacement if custom else _font
		var character := String.chr(glyph.code if custom else GlyphFont.BASE + index)
		var point: Vector2 = _point + Vector2(glyph.position) * (font_size / 12.0) + Vector2(0, font_size)
		var color := tint
		if custom and font_override == null and foreground:
			color *= GlyphFont.palette_color(_layout.palette[(glyph.color << 2) | 3])
		if custom and font_override == null:
			draw_fitted_glyph(glyph, _ink[index], offset, color)
			continue
		draw_char(font, point + offset, character, font_size, color)

func draw_fitted_glyph(glyph: Dictionary, ink: Rect2, offset: Vector2, color: Color) -> void:
	var bounds := PresentationFonts.dialogue_bounds(glyph.code)
	if not bounds.has_area() or not ink.has_area(): return
	var scale_factor := font_size / 12.0
	var fit := ink.size * scale_factor / bounds.size
	var origin := _point + (Vector2(glyph.position) + ink.position) * scale_factor + offset
	draw_set_transform(origin - bounds.position * fit, 0, fit)
	draw_char(presentation_font, Vector2.ZERO, String.chr(glyph.code), 96, color)
	draw_set_transform(Vector2.ZERO)
