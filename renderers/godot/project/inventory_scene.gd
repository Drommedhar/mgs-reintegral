@tool
extends "res://original_ui_scene.gd"

func label(parent: Node, name: String, rect: Rect2, text: String, font_size: int = 8) -> Label:
	var node := Label.new()
	node.clip_text = name == "Name"
	node.add_theme_font_size_override("font_size", font_size)
	node.text = text
	add(parent, name, node, rect)
	return node

func create(resources: RefCounted) -> Control:
	var art := preload("res://inventory_art.gd").new()
	error = art.initialize(resources)
	if not error.is_empty(): return null
	root = preload("res://inventory_ui.gd").new()
	root.name = "InventoryUi"
	root.size = Vector2(320,224)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.set_meta("mgs_ui_slot", "inventory")
	create_panel("Item", Vector2(16,184))
	create_panel("Weapon", Vector2(260,184))
	create_description()
	return root

func create_panel(name: String, origin: Vector2) -> void:
	var node: Control = preload("res://inventory_panel.gd").new()
	add(root, name, node, Rect2(origin, Vector2(47,29)))
	color(node, "Background", Rect2(10,1,35,19), Color(0,0,0,0.5))
	for part in [["Top",Rect2(0,0,47,1)], ["Left",Rect2(-4,0,14,20)], ["Right",Rect2(45,1,2,19)], ["Bottom",Rect2(-4,20,51,9)]]:
		color(node, part[0], part[1], Color.BLACK)
	texture(node, "Icon", Rect2(0,0,32,20))
	var title := label(node, "Name", Rect2(-4,22,50,5), "NO ITEM")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label(node, "Count", Rect2(0,11,46,7), "3/5")
	label(node, "Level", Rect2(0,14,18,5), "LV.")
	for badge in ["Disabled", "Frozen"]: texture(node, badge, Rect2())
	var magazine: Control = preload("res://inventory_magazine.gd").new()
	add(node, "Magazine", magazine, Rect2(45,20,0,9))

func create_description() -> void:
	var node := control(root, "Description", Rect2(86,72,200,80))
	node.z_index = 64
	color(node, "Background", Rect2(-10,0,210,80), Color(0,0,0,0.75))
	var header := Polygon2D.new()
	header.name = "Header"
	header.polygon = PackedVector2Array([Vector2(-10,-9),Vector2(36,-9),Vector2(46,0),Vector2(-10,0)])
	header.color = Color(0,0,0,0.75)
	node.add_child(header)
	header.owner = root
	label(node, "Title", Rect2(-8,-7,44,5), "EQUIP")
	var preview := label(node, "Preview", Rect2(0,0,200,80), "Restores your life.\nUse while equipped.", 12)
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview.size = Vector2(200,80)
	var text: Control = preload("res://subtitles_text.gd").new()
	text.outline_size = 0
	add(node, "Text", text, Rect2(0,0,200,80))
	texture(node, "PalKey", Rect2(144,44,0,0))
