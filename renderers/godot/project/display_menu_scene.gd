@tool
extends "res://original_ui_scene.gd"

func label(parent: Node, name: String, rect: Rect2, text: String) -> Label:
	var node := Label.new()
	node.add_theme_font_size_override("font_size", 8)
	node.theme = root.theme
	node.text = text
	return add(parent, name, node, rect)

func button(parent: Node, name: String, rect: Rect2, text: String) -> Button:
	var node := Button.new()
	node.add_theme_font_size_override("font_size", 8)
	node.theme = root.theme
	node.text = text
	add(parent, name, node, rect)
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	return node

func create(resources: RefCounted) -> Control:
	root = preload("res://display_menu_ui.gd").new()
	root.name = "DisplaySettingsUi"
	root.size = Vector2(320,224)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.set_meta("mgs_ui_slot", "display_settings")
	var theme := Theme.new()
	theme.default_font_size = 8
	for type in ["Label", "Button", "OptionButton", "CheckButton"]:
		theme.set_font_size("font_size", type, 8)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			theme.set_color(state, type, Color("6fcd9b"))
		theme.set_color("font_disabled_color", type, Color("35503f"))
		if type == "Label": continue
		var box := StyleBoxFlat.new()
		box.bg_color = Color("101d18")
		box.border_color = Color("2e483d")
		box.set_border_width_all(1)
		theme.set_stylebox("normal", type, box)
		var focus := box.duplicate()
		focus.border_color = Color("6fcd9b")
		for state in ["focus", "hover", "pressed"]: theme.set_stylebox(state, type, focus)
	root.theme = theme
	theme.default_font = resources.font("mgs/ui/menu_small")
	if theme.default_font == null:
		error = resources.error
		root.free()
		return null
	var panel := control(root, "Panel", Rect2(0,0,320,224))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	color(panel, "Background", Rect2(0,0,320,224), Color.BLACK)
	label(panel, "Title", Rect2(24,20,270,12), "DISPLAY SETTINGS")
	color(panel, "Rule", Rect2(24,36,272,1), Color("2e483d"))
	label(panel, "ResolutionLabel", Rect2(24,53,114,12), "RESOLUTION")
	var resolution := OptionButton.new()
	resolution.add_theme_font_size_override("font_size", 8)
	resolution.theme = theme
	add(panel, "Resolution", resolution, Rect2(140,49,156,20))
	resolution.mouse_filter = Control.MOUSE_FILTER_STOP
	var aspect := CheckButton.new()
	aspect.add_theme_font_size_override("font_size", 8)
	aspect.theme = theme
	aspect.text = "WIDESCREEN"
	add(panel, "Widescreen", aspect, Rect2(24,77,272,20))
	aspect.mouse_filter = Control.MOUSE_FILTER_STOP
	var fullscreen := CheckButton.new()
	fullscreen.add_theme_font_size_override("font_size", 8)
	fullscreen.theme = theme
	fullscreen.text = "FULLSCREEN"
	add(panel, "Fullscreen", fullscreen, Rect2(24,103,272,20))
	fullscreen.mouse_filter = Control.MOUSE_FILTER_STOP
	var status := label(panel, "Status", Rect2(24,133,272,36), "")
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button(panel, "Preview", Rect2(24,172,126,32), "APPLY PREVIEW")
	button(panel, "Close", Rect2(170,172,126,32), "BACK")
	button(panel, "Keep", Rect2(24,172,126,32), "KEEP CHANGES")
	button(panel, "Revert", Rect2(170,172,126,32), "REVERT")
	label(panel, "Hint", Rect2(24,213,272,8), "X / CROSS / A TO RETURN TO OPTIONS")
	error = root.bind_originals(resources)
	if not error.is_empty():
		root.free()
		return null
	panel.hide()
	panel.get_node("Keep").hide()
	panel.get_node("Revert").hide()
	root.detach_originals()
	return root
