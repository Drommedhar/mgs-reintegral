@tool
extends "res://original_ui_scene.gd"

func label(parent: Node, name: String, rect: Rect2, text: String, font_size: int = 8) -> Label:
	var node := Label.new()
	node.text = text
	node.set_meta("mgs_ui_font","mgs/ui/menu_small")
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",Color("6fcd9b"))
	return add(parent,name,node,rect)

func button(parent: Node, name: String, rect: Rect2, text: String = "") -> Button:
	var node := Button.new()
	node.theme = root.theme
	node.set_meta("mgs_ui_font","mgs/ui/menu_small")
	node.add_theme_font_size_override("font_size",8)
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		node.add_theme_color_override(state,Color("6fcd9b"))
	for state in ["normal","hover","pressed","disabled"]:
		node.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("6fcd9b")
	focus.set_border_width_all(1)
	node.add_theme_stylebox_override("focus",focus)
	node.text = text
	add(parent,name,node,rect)
	# Store authored offsets while off-tree theme minimums still use Godot's defaults.
	node.offset_right = rect.end.x
	node.offset_bottom = rect.end.y
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	return node

func create(resources: RefCounted) -> Control:
	root = preload("res://save_ui.gd").new()
	root.name = "SaveLoadUi"
	root.size = Vector2(320,224)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.set_meta("mgs_ui_slot","save_load")
	root.theme = Theme.new()
	root.theme.default_font_size = 8
	root.theme.default_font = resources.font("mgs/ui/menu_small")
	if root.theme.default_font == null:
		error = resources.error
		root.free()
		return null
	color(root,"Background",Rect2(0,0,320,224),Color.BLACK)
	var title := label(root,"Title",Rect2(26,24,80,12),"SAVE DATA",8)
	title.set_meta("mgs_ui_font","mgs/ui/menu_large")
	color(root,"TitleConnector",Rect2(108,26,52,1),Color("2e483d"))
	color(root,"TitleConnectorEnd",Rect2(159,26,1,10),Color("2e483d"))
	label(root,"Count",Rect2(55,38,210,8),"")
	var list := control(root,"SaveList",Rect2(55,51,210,132))
	for index in 6:
		var row := control(list,"Save%d" % index,Rect2(0,index*22,210,21))
		color(row,"Selection",Rect2(0,0,210,21),Color("2e483d"))
		color(row,"LeftBracket",Rect2(0,0,1,21),Color("2e483d"))
		color(row,"RightBracket",Rect2(209,0,1,21),Color("2e483d"))
		var location := label(row,"Location",Rect2(6,0,198,12),"",12)
		location.set_meta("mgs_ui_font","mgs/ui/subtitle")
		label(row,"Details",Rect2(6,14,198,7),"",8)
		button(row,"Activate",Rect2(0,0,210,21))
	label(root,"Empty",Rect2(61,65,198,12),"No saved games")
	var new_save := control(root,"NewSave",Rect2(55,187,210,18))
	color(new_save,"Selection",Rect2(0,0,210,18),Color("2e483d"))
	label(new_save,"Label",Rect2(6,5,198,10),"NEW SAVE",8)
	button(new_save,"Activate",Rect2(0,0,210,18))
	button(root,"Back",Rect2(267,208,40,14),"BACK")
	label(root,"Error",Rect2(55,38,252,10),"")
	var hint := label(root,"Hint",Rect2(10,211,250,10),"",8)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var dialog := control(root,"Dialog",Rect2(40,83,240,58))
	color(dialog,"Background",Rect2(0,0,240,58),Color.BLACK)
	label(dialog,"Message",Rect2(10,10,220,16),"",8)
	label(dialog,"Choices",Rect2(10,36,220,14),"",8)
	button(dialog,"Confirm",Rect2(10,34,100,16),"OVERWRITE")
	button(dialog,"Cancel",Rect2(130,34,100,16),"CANCEL")
	button(dialog,"Continue",Rect2(70,34,100,16),"CONTINUE")
	for parent in [new_save,dialog]:
		var extent: Vector2 = parent.size
		color(parent,"Top",Rect2(0,0,extent.x,1),Color("6fcd9b"))
		color(parent,"Bottom",Rect2(0,extent.y-1,extent.x,1),Color("6fcd9b"))
		color(parent,"Left",Rect2(0,0,1,extent.y),Color("6fcd9b"))
		color(parent,"Right",Rect2(extent.x-1,0,1,extent.y),Color("6fcd9b"))
	error = root.bind_originals(resources)
	if not error.is_empty():
		root.free()
		return null
	root.update_preview()
	root.detach_originals()
	return root
