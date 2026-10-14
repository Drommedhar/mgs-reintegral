@tool
extends "res://original_ui_scene.gd"

const ActionButton = preload("res://title_button.gd")
const Ui = preload("res://title_ui.gd")
const Art = preload("res://title_art.gd")
const Text = preload("res://subtitles_text.gd")

func create(resources: RefCounted) -> Control:
	root = Ui.new()
	root.name = "TitleUi"
	root.size = Vector2(320,224)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.clip_contents = true
	root.set_meta("mgs_ui_slot", "title")
	color(root,"Background",Rect2(0,0,320,224),Color.BLACK)
	var sections: Array[Control] = []
	for name in ["Title", "Special", "Selection", "Menu"]: sections.append(control(root,name,Rect2(0,0,320,224)))
	for index in Ui.Layout.ELEMENTS.size():
		var item: Array = Ui.Layout.ELEMENTS[index]
		var node := Art.new()
		node.native_element = index
		node.original_texture = item[1]
		node.native_rect = item[2]
		node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		add(sections[0 if index<22 else 1 if index<40 else 2 if index<49 else 3],item[0],node,item[2])
		if index == 12: button(node,6,0)
		elif index in range(49,54): button(node,7,index-49)
	button(control(sections[0],"SkipIntro",Rect2(0,0,320,224)),1,0)
	var difficulty := control(root,"Difficulty",Rect2(0,0,320,224))
	difficulty.z_index = 9
	for index in 5:
		label(difficulty,"Level%d" % index,Rect2([124,144,136,144,132][index],60+26*index,120,8),["VERY EASY","EASY","NORMAL","HARD","EXTREME"][index],false)
		button(difficulty.get_node("Level%d" % index),21,index)
	var storage := control(root,"StorageWarning",Rect2(0,0,320,224))
	storage.z_index = 9
	for index in 2:
		label(storage,"Slot%d"%index,Rect2(54,60+15*index,169,8),"MEMORY CARD SLOT %d  :  "%[index+1],false)
		label(storage,"Status%d"%index,Rect2(223,60+15*index,56,8),"NO CARD",false)
	label(storage,"Question",Rect2(70,100,200,8),"DO YOU WANT TO CONTINUE",false)
	label(storage,"QuestionEnd",Rect2(85,115,200,8),"YOUR GAME LIKE THIS?",false)
	label(storage,"Continue",Rect2(100,150,40,8),"YES",false)
	label(storage,"Cancel",Rect2(200,150,40,8),"NO",false)
	button(storage.get_node("Continue"),18,0)
	button(storage.get_node("Cancel"),18,1)
	var help := control(root,"Help",Rect2(0,0,320,224))
	help.z_index = 10
	for index in 24:
		var node := Text.new()
		node.set_meta("mgs_title_text",index)
		add(help,"Text%02d"%index,node,Rect2(0,0,320,224))
	error = root.bind_originals(resources)
	if not error.is_empty():
		root.free()
		return null
	root.detach_originals()
	return root

func label(parent: Control, name: String, rect: Rect2, text: String, centered: bool = true) -> void:
	var node := Label.new()
	node.text = text
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	node.add_theme_font_size_override("font_size",8)
	add(parent,name,node,rect)

func button(parent: Control, page: int, target: int) -> void:
	var node := ActionButton.new()
	node.native_page = page
	node.native_target = target
	node.flat = true
	for style in ["normal","hover","pressed","focus","disabled"]: node.add_theme_stylebox_override(style,StyleBoxEmpty.new())
	add(parent,"Interact",node,Rect2(Vector2.ZERO,parent.size))
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	node.mouse_filter = Control.MOUSE_FILTER_STOP
