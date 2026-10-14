@tool
extends "res://original_ui_scene.gd"

const Ui = preload("res://codec_ui.gd")
const Portrait = preload("res://codec_portrait.gd")
const Text = preload("res://subtitles_text.gd")
const ActionButton = preload("res://codec_button.gd")
const INK = Color8(46,71,61)
const DARK = Color8(19,31,26)
const DISPLAY_INK = Color8(41,66,58)

func create(resources: RefCounted) -> Control:
	root = Ui.new()
	root.name = "CodecUi"
	root.size = Vector2(320,224)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.set_meta("mgs_ui_slot", "codec")
	var panel := control(root, "Panel", Rect2(0,0,320,224))
	color(panel, "Background", Rect2(0,0,320,224), Color.BLACK)
	create_console(panel)
	for index in 2: create_portrait(panel, index)
	var message := Text.new()
	message.outline_size = 0
	add(panel,"Message",message,Rect2(0,0,320,224))
	label(panel,"PreviewMessage",Rect2(34,138,252,30),"Snake, do you read me?",Color8(206,206,206),12)
	label(panel,"ExitHint",Rect2(0,130,320,12),"PRESS SELECT TO EXIT",INK,8).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	triangle(panel,"Wait",Rect2(284,206,8,4),[Vector2(0,0),Vector2(8,0),Vector2(4,4)],Color.WHITE)
	create_memory(panel)
	var incoming := control(root,"Incoming",Rect2(130,49,60,26))
	texture(incoming,"Call",Rect2(0,0,60,12))
	label(incoming,"Hint",Rect2(-12,14,84,8),"PUSH SELECT",Color.WHITE,8).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	color(root,"Fade",Rect2(0,0,320,224),Color.BLACK)
	create_actions(panel,incoming)
	error = root.bind_originals(resources)
	if not error.is_empty():
		root.free()
		return null
	root.detach_originals()
	return root

func action_button(parent: Control, name: String, action: String, target: int, rect: Rect2) -> void:
	var node := ActionButton.new()
	node.native_action=action
	node.native_target=target
	for state in ["normal","hover","pressed","disabled","focus"]: node.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	add(parent,name,node,rect)
	node.mouse_filter=Control.MOUSE_FILTER_STOP
	node.z_index=10

func create_actions(panel: Control, incoming: Control) -> void:
	var console: Control = panel.get_node("Console")
	action_button(console,"CallButton","call",0,Rect2(39,0,62,14))
	action_button(console,"MemoryButton","memory",0,Rect2(39,75,62,14))
	action_button(console,"LeftButton","tune_step",-1,Rect2(0,35,25,20))
	action_button(console,"RightButton","tune_step",1,Rect2(115,35,25,20))
	action_button(panel,"BackButton","back",0,Rect2(60,128,200,13))
	for action in ["advance","skip","confirm"]:
		action_button(panel,action.capitalize()+"Button",action,-1 if action=="confirm" else 0,Rect2(30,142,265,70))
	for index in 8:
		action_button(panel.get_node("Contacts/Contact%d"%index),"Interact","contact",index,Rect2(0,0,138,16))
	action_button(incoming,"Interact","open",0,Rect2(0,0,60,26))

func label(parent: Node, name: String, rect: Rect2, text: String, tint: Color, font_size: int) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",tint)
	return add(parent,name,node,rect)

func triangle(parent: Node, name: String, rect: Rect2, points: Array, tint: Color) -> void:
	var node := control(parent,name,rect)
	var shape := Polygon2D.new()
	shape.name = "Shape"
	shape.polygon = PackedVector2Array(points)
	shape.color = tint
	node.add_child(shape)
	shape.owner = root

func create_console(panel: Control) -> void:
	var console := control(panel,"Console",Rect2(90,30,140,89))
	var rectangles := [Rect2(30,20,80,48),Rect2(26,17,5,2),Rect2(109,17,5,2),Rect2(26,69,5,2),Rect2(109,69,5,2),
		Rect2(31,17,78,1),Rect2(31,70,78,1),Rect2(39,0,62,10),Rect2(39,79,62,10),Rect2(0,38,25,11),Rect2(115,38,25,11),
		Rect2(-6,0,43,1),Rect2(103,0,43,1),Rect2(-6,88,43,1),Rect2(103,88,43,1),Rect2(1,8,36,1),Rect2(103,8,36,1),Rect2(1,80,36,1),Rect2(103,80,36,1)]
	for index in rectangles.size(): color(console,"Trim%d"%index,rectangles[index],Color8(32,48,41) if index in range(1,7) else DARK)
	label(console,"PTT",Rect2(54,2,32,8),"PTT",INK,8)
	label(console,"Memory",Rect2(44,81,60,8),"MEMORY",INK,8)
	triangle(console,"Left",Rect2(8,43,8,8),[Vector2(0,0),Vector2(8,-4),Vector2(8,4)],INK)
	triangle(console,"Right",Rect2(124,43,8,8),[Vector2(8,0),Vector2(0,-4),Vector2(0,4)],INK)
	var frequency := control(console,"Frequency",Rect2(51,48,62,17))
	var offsets := [0,10,20,35,47]
	for digit in 5:
		var small := digit < 2
		var node := control(frequency,"Digit%d"%digit,Rect2(offsets[digit],2 if small else 0,9,17))
		var segments := [Rect2(1,0,5,2),Rect2(0,1,2,6),Rect2(5,1,2,6),Rect2(1,6,5,2),Rect2(0,8,2,6),Rect2(5,8,2,6),Rect2(1,13,5,2)] if small else [Rect2(1,0,7,2),Rect2(0,1,2,7),Rect2(7,1,2,7),Rect2(1,7,7,2),Rect2(0,9,2,7),Rect2(7,9,2,7),Rect2(1,15,7,2)]
		for segment in 7: color(node,"Segment%d"%segment,segments[segment],DISPLAY_INK)
	color(frequency,"Decimal",Rect2(31,15,2,2),DISPLAY_INK)
	var signal_bars := control(console,"Signal",Rect2(32,21,76,44))
	for row in range(1,44):
		if row % 5: color(signal_bars,"Row%d"%row,Rect2(0,row,mini(76,300/row+3),1),DISPLAY_INK)
	create_console_foreground(console)

func create_console_foreground(console: Control) -> void:
	var foreground := CanvasGroup.new()
	foreground.name = "Foreground"
	foreground.fit_margin = 2
	foreground.clear_margin = 2
	console.add_child(foreground)
	foreground.owner = root
	var shader := Shader.new()
	# Original radio.c combines the center with four half-weight and four quarter-weight copies.
	shader.code = """shader_type canvas_item;
render_mode unshaded, blend_add;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
varying vec2 pixel_x;
varying vec2 pixel_y;
void vertex() {
	mat4 transform = CANVAS_MATRIX * MODEL_MATRIX;
	pixel_x = transform[0].xy;
	pixel_y = transform[1].xy;
}
void fragment() {
	vec3 glow = vec3(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 offset = (float(x) * pixel_x + float(y) * pixel_y) * SCREEN_PIXEL_SIZE;
			float weight = (x == 0 ? 1.0 : 0.5) * (y == 0 ? 1.0 : 0.5);
			vec3 source = floor(textureLod(screen_texture, SCREEN_UV + offset, 0.0).rgb * 255.0 / 8.0 + 0.01);
			glow += floor(source * weight) / 31.0;
		}
	}
	COLOR *= vec4(glow, 1.0);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	foreground.material = material
	for name in ["Frequency","Signal","PTT","Memory","Left","Right"]:
		var node: Node = console.get_node(name).duplicate()
		foreground.add_child(node)
		node.owner = root
		for child in node.find_children("*","",true,false): child.owner = root

func create_portrait(panel: Control, side: int) -> void:
	var portrait := control(panel,"LeftPortrait" if side == 0 else "RightPortrait",Rect2(31 if side == 0 else 237,30,52,89))
	for name in ["Current","Previous"]:
		var image := Portrait.new()
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		add(portrait,name,image,Rect2(0,0,52,89))
		blend(image,CanvasItemMaterial.BLEND_MODE_ADD)
	var border := NinePatchRect.new()
	border.draw_center = false
	for property in ["patch_margin_left","patch_margin_top","patch_margin_right","patch_margin_bottom"]: border.set(property,9)
	add(portrait,"Frame",border,Rect2(-3,-3,58,95))
	blend(border,CanvasItemMaterial.BLEND_MODE_ADD)
	color(portrait,"Scanline",Rect2(0,0,52,1),Color8(8,8,8))
	blend(portrait.get_node("Scanline"),CanvasItemMaterial.BLEND_MODE_ADD)
	var bracket := control(panel,"LeftBracket" if side == 0 else "RightBracket",Rect2(24 if side == 0 else 290,30,6,89))
	color(bracket,"Top",Rect2(0,0,6,1),DARK)
	color(bracket,"Side",Rect2(0 if side == 0 else 5,0,1,89),DARK)
	color(bracket,"Bottom",Rect2(0,88,6,1),DARK)

func create_memory(panel: Control) -> void:
	var memory := control(panel,"Contacts",Rect2(0,0,320,224))
	for index in 8:
		var row := control(memory,"Contact%d"%index,Rect2(22+(index%2)*138,133+(index/2)*20,138,16))
		color(row,"Background",Rect2(0,0,138,16),Color.BLACK)
		color(row,"FrequencyPanel",Rect2(3,1,35,9),DARK)
		color(row,"Underline",Rect2(1,12,136,1),DARK)
		label(row,"Frequency",Rect2(4,3,18,7),"140",INK,8)
		color(row,"FrequencyDot",Rect2(22,6,1,2),INK)
		label(row,"FrequencyFraction",Rect2(24,3,12,7),"85",INK,8)
		var text := Text.new()
		text.outline_size = 0
		add(row,"Name",text,Rect2(42,0,96,12))
		label(row,"Preview",Rect2(42,0,96,12),["CAMPBELL","MEI LING","NAOMI","NASTASHA"][index%4],INK,8)
	triangle(memory,"Up",Rect2(155,120,10,5),[Vector2(0,5),Vector2(5,0),Vector2(10,5)],INK)
	triangle(memory,"Down",Rect2(156,212,8,4),[Vector2(0,0),Vector2(4,4),Vector2(8,0)],INK)
