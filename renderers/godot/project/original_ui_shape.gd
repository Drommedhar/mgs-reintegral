@tool
extends Control

@export var source_id := ""
@export var shape_index := 0
@export_range(0.1, 16.0) var line_width := 1.0:
	set(value):
		line_width = value
		queue_redraw()
var _points := PackedVector2Array()
var _color := Color.WHITE
var _polygon := false

func bind(resources: RefCounted) -> String:
	_points.clear()
	queue_redraw()
	var layout: Dictionary = resources.layout(source_id)
	if layout.is_empty(): return resources.error
	if shape_index < 0 or shape_index >= layout.shapes.size(): return "Original UI shape index is outside its layout"
	var shape = layout.shapes[shape_index]
	if not shape is Dictionary: return "Invalid original UI shape"
	if shape.get("type") not in ["line", "polygon"] or not shape.get("points") is Array or not shape.get("color") is Array or shape.color.size() != 3 or shape.get("blend") not in [0.0, 1.0, 2.0, 3.0]:
		return "Invalid original UI shape"
	var points := PackedVector2Array()
	for channel in shape.color:
		if not channel is float or not is_finite(channel) or channel < 0 or channel > 255: return "Invalid original UI shape color"
	for point in shape.points:
		if not point is Array or point.size() != 2 or not point[0] is float or not point[1] is float:
			return "Invalid original UI shape coordinates"
		if not is_finite(point[0]) or not is_finite(point[1]): return "Invalid original UI shape coordinates"
		points.append(Vector2(point[0], point[1]))
	_polygon = shape.type == "polygon"
	if points.size() < (3 if _polygon else 2): return "Original UI shape has too few points"
	_points = points
	_color = Color(shape.color[0] / 255.0, shape.color[1] / 255.0, shape.color[2] / 255.0, 0.5 if shape.blend == 0 else 1.0)
	if shape.blend == 3: _color *= Color(0.25, 0.25, 0.25, 1.0)
	if material == null:
		var canvas := CanvasItemMaterial.new()
		canvas.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX if shape.blend == 0 else CanvasItemMaterial.BLEND_MODE_SUB if shape.blend == 2 else CanvasItemMaterial.BLEND_MODE_ADD
		material = canvas
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()
	return ""

func _draw() -> void:
	if _points.is_empty(): return
	if _polygon: draw_colored_polygon(_points, _color)
	else: draw_polyline(_points, _color, line_width)
