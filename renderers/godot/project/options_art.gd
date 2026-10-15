@tool
extends TextureRect

@export_range(0,56) var native_element := 0
@export var original_texture := ""
@export var native_rect := Rect2()
@export var use_native_position := true
@export var use_native_color := true
@export var use_native_texture := true
var _authored: Dictionary = {}
var _applied: Dictionary = {}
var _layer_count := 4

func remember_edits() -> void:
	for key in _authored:
		var value = get(key)
		if value != _applied.get(key,value):
			_authored[key] = _authored[key]+value-_applied[key] if value is Vector2 else value

func remember() -> void:
	if not _authored.is_empty(): return
	for key in ["position","size","visible","self_modulate","z_index","material"]: _authored[key] = get(key)
	_applied = _authored.duplicate()

func apply_element(element: Dictionary, textures: Dictionary) -> void:
	remember()
	remember_edits()
	visible = _authored.visible and element.get("layer",0)>0
	if use_native_position:
		position = _authored.position + element.get("position",native_rect.position) - native_rect.position
		size = _authored.size * element.get("size",native_rect.size) / native_rect.size.max(Vector2.ONE)
	self_modulate = _authored.self_modulate
	if use_native_color:
		var rgb: int = element.get("rgb",0x808080)
		self_modulate = _authored.self_modulate * Color((rgb&255)/128.0,((rgb>>8)&255)/128.0,((rgb>>16)&255)/128.0,1)
	if use_native_texture and (texture == null or texture.has_meta("mgs_retail_derived")):
		texture = textures.get(element.get("texture",0))
	z_index = _authored.z_index + _layer_count - int(element.get("layer",0))
	apply_material(element)
	for key in _authored: _applied[key] = get(key)

func apply_material(element: Dictionary) -> void:
	if _authored.material == null:
		var blend: int = element.get("blend",0)
		var canvas := material as CanvasItemMaterial
		if canvas == null: canvas = CanvasItemMaterial.new()
		canvas.blend_mode = CanvasItemMaterial.BLEND_MODE_SUB if blend == 3 else CanvasItemMaterial.BLEND_MODE_ADD if blend in [2,4] else CanvasItemMaterial.BLEND_MODE_MIX
		material = canvas
		if blend == 1: self_modulate.a *= 0.5
		if blend == 4: self_modulate *= Color(0.25,0.25,0.25,1)

func detach_originals() -> void:
	remember_edits()
	for key in _authored: set(key,_authored[key])
	if texture != null and texture.has_meta("mgs_retail_derived"): texture = null
	_authored.clear()
	_applied.clear()
