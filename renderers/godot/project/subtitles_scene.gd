@tool
extends RefCounted

var error := ""

func create(_resources: RefCounted) -> Control:
	var root := preload("res://subtitles_ui.gd").new()
	root.name = "Subtitles"
	root.size = Vector2(320, 224)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.set_meta("mgs_ui_slot", "subtitles")
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.size = root.size
	dim.color = Color(0, 0, 0, 0.5)
	dim.visible = false
	var pause := Label.new()
	pause.name = "Pause"
	pause.text = "PAUSE"
	pause.position = Vector2(0, 80)
	pause.size = Vector2(320, 8)
	pause.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause.add_theme_font_size_override("font_size", 8)
	pause.add_theme_color_override("font_color", Color(200.0 / 128, 200.0 / 128, 200.0 / 128))
	pause.visible = false
	var text := preload("res://subtitles_text.gd").new()
	text.name = "Text"
	text.size = root.size
	for node in [dim, pause, text]:
		root.add_child(node)
		node.owner = root
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return root
