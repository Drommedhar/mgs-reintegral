@tool
extends RefCounted

const Ui = preload("res://goggles_ui.gd")
const Shape = preload("res://original_ui_shape.gd")
var error := ""
var root: Control

func add(parent: Node, node: Node, node_name: String, role: String = "", index: int = 0) -> Node:
	node.name = node_name
	parent.add_child(node)
	node.owner = root
	if node is Control: node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not role.is_empty():
		node.set_meta("mgs_ui_role", role)
		node.set_meta("mgs_ui_index", index)
	return node

func label(parent: Node, node_name: String, text: String, point: Vector2, large: bool, color: Color, role: String = "", index: int = 0) -> Label:
	var node := Label.new()
	node.text = text
	node.position = point
	node.add_theme_color_override("font_color", color)
	node.add_theme_font_size_override("font_size", 8)
	node.set_meta("mgs_ui_font", "mgs/ui/menu_large" if large else "mgs/ui/menu_small")
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	node.material = material
	return add(parent, node, node_name, role, index)

func rect(parent: Node, node_name: String, point: Vector2, extent: Vector2, color: Color, role: String, index: int) -> Control:
	var node := ColorRect.new()
	node.position = point
	node.size = extent
	node.color = color
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	node.material = material
	return add(parent, node, node_name, role, index)

func create(resources: RefCounted) -> Control:
	error = ""
	root = Ui.new()
	root.name = "Goggles"
	root.size = Vector2(320, 224)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.set_meta("mgs_ui_slot", "goggles")
	for mode in ["night", "thermal"]:
		var group: Control = add(root, Control.new(), "NightVision" if mode == "night" else "ThermalVision", mode)
		for layer in 3:
			var holder: Control = add(group, Control.new(), "SightLayer%d" % layer, "layer", layer)
			var identity := "mgs/ui/%s%d" % ["nv_ggle" if mode == "night" else "ir_ggle", layer + 1]
			var layout: Dictionary = resources.layout(identity)
			if layout.is_empty():
				error = resources.error
				root.free()
				return null
			for index in layout.draw_order:
				var shape := Shape.new()
				shape.source_id = identity
				shape.shape_index = int(index)
				add(holder, shape, "Shape%03d" % index)
		add_hud(group, mode)
	return root

func add_hud(group: Control, mode: String) -> void:
	var hud: Control = add(group, Control.new(), "Indicators", "hud")
	var text_color := Color(255.0 / 128, 0, 0) if mode == "night" else Color(65.0 / 128, 160.0 / 128, 74.0 / 128)
	var color := Color(1, 0, 0) if mode == "night" else Color8(65, 160, 74)
	label(hud, "Scan", "SCAN", Vector2(41, 42), true, text_color, "scan")
	label(hud, "Mode", "MODE - B" if mode == "night" else "MODE - A", Vector2(137, 42), true, text_color)
	for index in 3:
		label(hud, "Vector%d" % index, "0", Vector2(40, 56 + index * 8), false, text_color, "vector", index)
		rect(hud, "Bar%d" % index, Vector2(40 + index * 12, 140), Vector2(3, 0), color, "bar", index)
		rect(hud, "Cap%d" % index, Vector2(43 + index * 12, 140), Vector2(4, 1), color, "cap", index)
	for index in 13:
		var number := label(hud, "Heading%d" % index, "00", Vector2(-8, 148), false, text_color, "heading", index)
		number.size.x = 16
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rect(hud, "Tick%d" % index, Vector2(0, 144), Vector2.ONE, color, "tick", index)
