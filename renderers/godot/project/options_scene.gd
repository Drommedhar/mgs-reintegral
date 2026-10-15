@tool
extends "res://original_ui_scene.gd"

const Ui = preload("res://options_ui.gd")
const Art = preload("res://options_art.gd")
const Text = preload("res://subtitles_text.gd")
const ActionButton = preload("res://options_button.gd")

func action_button(parent: Control, action: String, option: int = 0, value: int = 0) -> void:
	var button := ActionButton.new()
	button.native_action = action
	button.native_option = option
	button.native_value = value
	button.tooltip_text = parent.name
	for state in ["normal","hover","pressed","disabled","focus"]:
		button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	button.add_theme_font_size_override("font_size",1)
	add(parent,"Interact",button,Rect2(Vector2.ZERO,parent.size))
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.z_index = 10

func actions() -> void:
	for item in [["Captions",1],["Language",2],["Sound",3],["Vibration",4],["VibrationTest",5]]:
		action_button(root.get_node("Options/"+item[0]),"select",item[1])
	for item in [["CaptionOn",1,0],["CaptionOff",1,1],["Japanese",2,0],["English",2,1],
		["Stereo",3,0],["Monaural",3,1],["VibrationOn",4,0],["VibrationOff",4,1],["Weak",5,0],["Strong",5,1]]:
		action_button(root.get_node("Options/"+item[0]),"set",item[1],item[2])
	for item in [["Screen",6],["Controller",8],["Exit",10]]:
		action_button(root.get_node("Options/"+item[0]),"activate",item[1])
	for item in [["ButtonMapping",0],["FirstPerson",1]]:
		action_button(root.get_node("Controller/"+item[0]),"select",item[1])
	for item in [["TypeA",0,0],["TypeB",0,1],["TypeC",0,2],["Normal",1,0],["Reverse",1,1]]:
		action_button(root.get_node("Controller/"+item[0]),"set",item[1],item[2])
	for path in ["ScreenAdjustment/ScreenExit","Controller/ControllerExit"]:
		action_button(root.get_node(path),"back")

func create(resources: RefCounted) -> Control:
	root = Ui.new()
	root.name = "OptionsUi"
	root.size = Vector2(320,224)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.set_meta("mgs_ui_slot","options")
	color(root,"Background",Rect2(0,0,320,224),Color.BLACK)
	var sections: Array[Control] = []
	for name in ["Options","ScreenAdjustment","Controller","Selection"]:
		sections.append(control(root,name,Rect2(0,0,320,224)))
	for index in Ui.Layout.ELEMENTS.size():
		var element: Array = Ui.Layout.ELEMENTS[index]
		var node := Art.new()
		node.native_element = index
		node.original_texture = element[1]
		node.native_rect = element[2]
		node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		add(sections[0 if index<27 else 1 if index<31 else 2 if index<48 else 3],element[0],node,element[2])
	actions()
	var help := control(root,"Help",Rect2(0,0,320,224))
	help.z_index = 5
	for index in 31:
		var node := Text.new()
		node.set_meta("mgs_options_text",index)
		add(help,"Text%02d"%index,node,Rect2(0,0,320,224))
	var message := Label.new()
	message.add_theme_font_size_override("font_size",8)
	message.add_theme_color_override("font_color",Color("6fcd9b"))
	message.clip_text = true
	message.visible = false
	message.z_index = 10
	add(root,"ActionError",message,Rect2(8,214,304,10))
	error = root.bind_originals(resources)
	if not error.is_empty():
		root.free()
		return null
	root.detach_originals()
	return root
