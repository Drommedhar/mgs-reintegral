@tool
extends RefCounted

const Ui = preload("res://bars_ui.gd")
const Bar = preload("res://status_bar.gd")
var error := ""
var root: Control
var font: FontFile

func add(parent: Node, node: Control, node_name: String, point: Vector2, extent: Vector2, role: String = "") -> Control:
	node.name = node_name
	parent.add_child(node)
	node.owner = root
	node.position = point
	node.size = extent
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not role.is_empty(): node.set_meta("mgs_bar_role", role)
	return node

func rect(parent: Node, node_name: String, point: Vector2, extent: Vector2, color: Color, role: String) -> ColorRect:
	var node := ColorRect.new()
	node.color = color
	return add(parent, node, node_name, point, extent, role)

func create(resources: RefCounted) -> Control:
	font = resources.font("mgs/ui/menu_small")
	if font == null:
		error = resources.error
		return null
	root = Ui.new()
	root.name = "StatusBars"
	root.size = Vector2(320, 224)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.set_meta("mgs_ui_slot", "bars")
	for kind in [1, 2, 0]: create_bar(kind)
	return root

func create_bar(kind: int) -> void:
	var bar := Bar.new()
	bar.kind = kind
	bar.native_origin = Vector2(16, 16 if kind == 1 else 28)
	bar.use_native_colors = kind == 0
	bar.use_native_name = kind == 0
	var height := 4 if kind == 2 else 5
	var point := bar.native_origin
	add(root, bar, "Life" if kind == 1 else "Oxygen" if kind == 2 else "Other", point, Vector2(128, height + 2))
	rect(bar, "Background", Vector2(0, 1), Vector2(128, height), Color(0, 24.0 / 255, 24.0 / 255, 0.5), "background")
	var fill := add(bar, Control.new(), "Fill", Vector2(0, 1), Vector2(128, height), "fill")
	fill.clip_contents = true
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color8(31, 63, 192), Color8(31, 127, 255)] if kind == 2 else [Color8(16, 143, 127), Color8(31, 223, 63)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 128
	texture.height = 1
	texture.fill_to = Vector2(1, 0)
	var image := TextureRect.new()
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add(fill, image, "Gradient", Vector2.ZERO, Vector2(128, height), "gradient")
	rect(bar, "Damage", Vector2(0, 1), Vector2(0, height), Color8(200, 0, 0), "damage")
	rect(bar, "BorderLeft", Vector2(-1, 0), Vector2(1, height + 2), Color.BLACK, "left")
	rect(bar, "BorderRight", Vector2(128, 0), Vector2(1, height + 2), Color.BLACK, "right")
	rect(bar, "BorderTop", Vector2.ZERO, Vector2(128, 1), Color.BLACK, "top")
	rect(bar, "BorderBottom", Vector2(0, height + 1), Vector2(128, 1), Color.BLACK, "bottom")
	rect(bar, "NameBackground", Vector2(3, 3), Vector2(22, 7), Color(0, 0, 0, 0.5), "label_background")
	var label := Label.new()
	label.text = "LIFE" if kind == 1 else "O2" if kind == 2 else "BOSS"
	label.add_theme_color_override("font_color", Color(255.0 / 128, 255.0 / 128, 255.0 / 128))
	label.add_theme_font_size_override("font_size", 8)
	label.set_meta("mgs_ui_font", "mgs/ui/menu_small")
	add(bar, label, "Name", Vector2(4, 4), Vector2.ZERO, "label")
	bar.get_node("NameBackground").size.x = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 2
