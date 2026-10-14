@tool
extends RefCounted

var root: Control
var error := ""

func add(parent: Node, name: String, node: Control, rect: Rect2) -> Control:
	# Original fonts bind after construction; system metrics must not expand native rectangles.
	if node is Label:
		node.clip_text = true
		node.reset_size()
	node.name = name
	parent.add_child(node)
	node.owner = root
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func control(parent: Node, name: String, rect: Rect2, clip: bool = false) -> Control:
	var node := Control.new()
	node.clip_contents = clip
	return add(parent, name, node, rect)

func color(parent: Node, name: String, rect: Rect2, tint: Color) -> ColorRect:
	var node := ColorRect.new()
	node.color = tint
	return add(parent, name, node, rect)

func texture(parent: Node, name: String, rect: Rect2) -> TextureRect:
	var node := TextureRect.new()
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	return add(parent, name, node, rect)

func blend(node: CanvasItem, mode: int) -> void:
	var material := CanvasItemMaterial.new()
	material.blend_mode = mode
	node.material = material
