@tool
extends RefCounted

const Provenance = preload("res://prepared_catalog.gd")
const KcbFont = preload("res://original_kcb_font.gd")
const PresentationFonts = preload("res://presentation_fonts.gd")
const SHARED = {"menu_small": "c70e.r", "menu_large": "5d43.r", "subtitle": "ca68.r", "nv_ggle1": "8504.s", "nv_ggle2": "8505.s", "nv_ggle3": "8506.s", "ir_ggle1": "84db.s", "ir_ggle2": "84dc.s", "ir_ggle3": "84dd.s"}
var root := ""
var assets: Dictionary = {}
var fonts: Dictionary = {}
var layouts: Dictionary = {}
var disc := 1
var error := ""

func configure(directory: String, catalog: Dictionary, source_disc: int = 1) -> void:
	root = directory
	assets = catalog
	fonts.clear()
	layouts.clear()
	disc = source_disc
	error = ""

func resolve(identity: String) -> String:
	if identity in ["mgs/ui/radar", "mgs/ui/inventory", "mgs/ui/codec"]: return "mgs/integral-j/disc%d/stage/init/%s" % [disc, identity.get_file()]
	if not identity.begins_with("mgs/ui/"): return identity
	return "mgs/integral-j/disc%d/stage/init/%s" % [disc, SHARED.get(identity.trim_prefix("mgs/ui/"), "")]

func bind_dialogue_fonts(scene: Node) -> void:
	for node in scene.find_children("*", "Control", true, false):
		if node.has_method("bind_presentation_font"):
			node.bind_presentation_font(PresentationFonts.dialogue_font())

func document(identity: String, kind: String) -> Dictionary:
	error = ""
	identity = resolve(identity)
	var asset: Dictionary = assets.get(identity, {})
	if asset.get("kind") != kind or not asset.has("preparedFiles"):
		error = "Original UI resource is not prepared: " + identity
		return {}
	var validator := Provenance.new()
	error = validator.validate(root, {identity: asset})
	if not error.is_empty(): return {}
	var value = JSON.parse_string(FileAccess.get_file_as_string(root.path_join(asset.path)))
	if not value is Dictionary or value.get("schema") != 1:
		error = "Invalid original UI document: " + identity
		return {}
	return value

func layout(identity: String) -> Dictionary:
	if layouts.has(identity): return layouts[identity]
	var value := document(identity, "ui_layout")
	if not value.is_empty() and (value.get("size") != [320.0, 224.0] or not value.get("shapes") is Array):
		error = "Invalid original sight layout: " + identity
		return {}
	if not value.is_empty(): layouts[identity] = value
	return value

func texture(identity: String) -> ImageTexture:
	error = ""
	var asset: Dictionary = assets.get(identity, {})
	if asset.get("kind") != "texture" or not asset.has("preparedFiles"):
		error = "Prepare original UI texture: " + identity
		return null
	var validator := Provenance.new()
	error = validator.validate(root, {identity: asset})
	if not error.is_empty(): return null
	var image := Image.load_from_file(root.path_join(asset.path))
	if image == null or asset.get("size") != [float(image.get_width()), float(image.get_height())]:
		error = "Original UI texture dimensions differ: " + identity
		return null
	var result := ImageTexture.create_from_image(image)
	result.set_meta("mgs_retail_derived", true)
	return result

func font(identity: String) -> FontFile:
	error = ""
	if fonts.has(identity): return fonts[identity]
	var value := document(identity, "ui_font")
	if value.is_empty(): return null
	var kcb: bool = value.get("format") == "kcb"
	var valid: bool = KcbFont.valid_document(value) if kcb else not value.has("format") and value.get("glyphs") is Dictionary and value.get("line_height") == 8 and value.get("height") in [5.0, 6.0]
	if not valid:
		error = "Invalid original UI font: " + identity
		return null
	var path: String = root.path_join(assets[resolve(identity)].path).get_base_dir().path_join(value.texture)
	var image := Image.load_from_file(path)
	if image == null or value.get("size") != [float(image.get_width()), float(image.get_height())]:
		error = "Original UI font atlas dimensions differ: " + identity
		return null
	if not (KcbFont.valid_glyphs(value) if kcb else valid_glyphs(value.glyphs, image.get_size())):
		error = "Original UI font contains invalid glyph metrics: " + identity
		return null
	var sharp := not kcb and identity in ["mgs/ui/menu_small", "mgs/ui/menu_large"] and PresentationFonts.enabled()
	if sharp:
		image = PresentationFonts.block_image(value, image)
		if image == null:
			error = "Cannot load presentation font atlas"
			return null
	var result := build_font(value, image, 12 if kcb else 8, PresentationFonts.SCALE if sharp else 1)
	fonts[identity] = result
	return result

static func build_font(value: Dictionary, image: Image, font_size: int, coverage_scale: int = 1) -> FontFile:
	var result := FontFile.new()
	result.set_meta("mgs_retail_derived", true)
	result.allow_system_fallback = false
	result.fixed_size = font_size
	result.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_ENABLED
	result.modulate_color_glyphs = true
	result.set_cache_ascent(0, font_size, value.height)
	result.set_cache_descent(0, font_size, value.line_height - value.height)
	result.set_texture_image(0, Vector2i(font_size, 0), 0, image)
	for character in value.glyphs:
		var glyph: Dictionary = value.glyphs[character]
		var code := int(character)
		var rect := Rect2(glyph.rect[0], glyph.rect[1], glyph.rect[2], glyph.rect[3])
		result.set_glyph_advance(0, font_size, code, Vector2(glyph.advance, 0))
		result.set_glyph_offset(0, Vector2i(font_size, 0), code, Vector2(glyph.offset, glyph.get("offset_y", 0) - value.height))
		result.set_glyph_size(0, Vector2i(font_size, 0), code, rect.size)
		result.set_glyph_uv_rect(0, Vector2i(font_size, 0), code, Rect2(rect.position * coverage_scale, rect.size * coverage_scale))
		result.set_glyph_texture_idx(0, Vector2i(font_size, 0), code, 0)
	return result

static func valid_glyphs(glyphs: Dictionary, size: Vector2i) -> bool:
	if glyphs.is_empty() or glyphs.size() > 256: return false
	for character in glyphs:
		if not character is String or not character.is_valid_int() or int(character) < 32 or int(character) > 126: return false
		var entry = glyphs[character]
		if not entry is Dictionary: return false
		var rect = entry.get("rect")
		if not rect is Array or rect.size() != 4: return false
		for value in rect + [entry.get("advance"), entry.get("offset")]:
			if not value is float or not is_finite(value) or value < 0 or value != floor(value): return false
		if rect[0] + rect[2] > size.x or rect[1] + rect[3] > size.y or entry.advance > 32 or entry.offset > 8: return false
	return true
