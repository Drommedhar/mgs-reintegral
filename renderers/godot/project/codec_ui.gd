@tool
extends Control

signal native_state_changed(state: Dictionary)

@export_enum("Conversation", "Tuning", "Contacts", "Incoming") var preview_mode := 0:
	set(value):
		preview_mode = value
		if Engine.is_editor_hint(): update_preview.call_deferred()
var _layout: Dictionary = {}
var _last: Dictionary = {}
var _bound := false
var controls := preload("codec_controls.gd").new()

func connect_provider(provider: Node) -> void:
	controls.connect_provider(self,provider)

func _input(event: InputEvent) -> void:
	controls.input(event)

func bind_originals(resources: RefCounted) -> String:
	resources.bind_dialogue_fonts(self)
	var font: Font = resources.font("mgs/ui/menu_small")
	if font == null: return resources.error
	var large_font: Font = resources.font("mgs/ui/menu_large")
	if large_font == null: return resources.error
	var ptt_font := FontVariation.new()
	ptt_font.base_font = large_font
	ptt_font.spacing_glyph = 3
	ptt_font.set_meta("mgs_retail_derived", true)
	var message_font: Font = resources.font("mgs/ui/subtitle")
	if message_font == null: return resources.error
	var document: Dictionary = resources.document("mgs/ui/codec", "ui_atlas")
	if document.is_empty(): return resources.error
	var asset: Dictionary = resources.assets[resources.resolve("mgs/ui/codec")]
	var textures := {}
	for key in ["frame","call"]:
		var entry: Dictionary = document.get("textures", {}).get(key,{})
		var file: String = entry.get("texture", "")
		var path: String = asset.path.get_base_dir().path_join(file)
		if file.is_empty() or file != file.get_file() or not asset.preparedFiles.has(path): return "Unverified Codec artwork"
		var image := Image.load_from_file(resources.root.path_join(path))
		if image == null or entry.get("size") != [float(image.get_width()),float(image.get_height())]: return "Invalid Codec artwork dimensions"
		textures[key] = ImageTexture.create_from_image(image)
		textures[key].set_meta("mgs_retail_derived",true)
	for node in find_children("*","Control",true,false):
		remember(node)
		if node is Label and (not node.has_theme_font_override("font") or node.get_theme_font("font").has_meta("mgs_retail_derived")):
			var selected: Font = message_font if node.name == "PreviewMessage" else font
			if node.name == "Memory": selected = large_font
			if node.name == "PTT": selected = ptt_font
			node.add_theme_font_override("font", selected)
	for path in ["Panel/LeftPortrait/Frame","Panel/RightPortrait/Frame","Incoming/Call"]:
		var node: Control = get_node(path)
		if node.texture == null or node.texture.has_meta("mgs_retail_derived"): node.texture = textures["call" if path == "Incoming/Call" else "frame"]
	_bound = true
	remember_applied()
	return ""

func remember(node: Control) -> void:
	if node is Button or node.name=="ActionError": return
	if _layout.has(node): return
	_layout[node] = {"position":node.position,"scale":node.scale,"visible":node.visible,"self_modulate":node.self_modulate,"modulate":node.modulate}
	if node is Label: _layout[node].text = node.text

func restore() -> void:
	for node in _layout:
		for property in _layout[node]: node.set(property,_layout[node][property])

func remember_edits() -> void:
	for node in _layout:
		if not _last.has(node): continue
		for property in _layout[node]:
			var value = node.get(property)
			var previous = _last[node][property]
			if value != previous:
				_layout[node][property] = _layout[node][property] + value - previous if value is Vector2 else value

func remember_applied() -> void:
	for node in _layout:
		_last[node] = {}
		for property in _layout[node]: _last[node][property] = node.get(property)

func detach_originals() -> void:
	remember_edits()
	restore()
	for node in find_children("*","Control",true,false):
		if node is Label and node.has_theme_font_override("font") and node.get_theme_font("font").has_meta("mgs_retail_derived"): node.remove_theme_font_override("font")
		if (node is TextureRect or node is NinePatchRect) and node.texture != null and node.texture.has_meta("mgs_retail_derived"): node.texture = null
		if node.has_method("detach_originals"): node.detach_originals()
	_layout.clear()
	_last.clear()
	_bound = false

func show_native(path: String, enabled: bool) -> void:
	var node: Control = get_node(path)
	node.visible = _layout[node].visible and enabled

func apply_native_state(state: Dictionary) -> void:
	if not _bound: return
	remember_edits()
	restore()
	show_native("Panel",state.get("active",false) and not state.get("incoming",false))
	show_native("Incoming",state.get("incoming",false))
	show_native("Panel/ExitHint",state.get("exit_hint",false))
	show_native("Panel/Wait",state.get("wait_mark",false))
	show_native("Panel/PreviewMessage",false)
	show_native("Fade",state.get("fade",0)>0)
	get_node("Fade").self_modulate.a = state.get("fade",0)/255.0
	var message: Dictionary = state.get("message",{})
	get_node("Panel/Message").apply_native_state(message if not state.get("memory",false) else {})
	apply_console(state)
	for side in 2: apply_portrait(state,side)
	apply_contacts(state)
	remember_applied()
	controls.artwork=state
	controls.refresh()
	native_state_changed.emit(state.duplicate(true))

func apply_console(state: Dictionary) -> void:
	var digits := "%05d" % state.get("frequency",14085)
	var bits := [0x77,0x24,0x5d,0x6d,0x2e,0x6b,0x7b,0x25,0x7f,0x6f]
	for digit in 5:
		for segment in 7:
			show_native("Panel/Console/Foreground/Frequency/Digit%d/Segment%d"%[digit,segment],bits[int(digits[digit])] & (1 << segment) != 0)
	for row in range(1,44):
		if row % 5: show_native("Panel/Console/Foreground/Signal/Row%d"%row,state.get("signal",0)*5>44-row)
	for pair in [["PTT",1],["Memory",2],["Right",4],["Left",8]]:
		show_native("Panel/Console/Foreground/"+pair[0],state.get("action",0)&pair[1] != 0)

func apply_portrait(state: Dictionary, side: int) -> void:
	var path := "Panel/" + ("LeftPortrait" if side == 0 else "RightPortrait")
	var node: Control = get_node(path)
	var face: Dictionary = state.faces[side] if state.get("faces",[]).size() == 2 else {}
	show_native(path,face.get("visible",false))
	var bracket: Control = get_node("Panel/"+("LeftBracket" if side == 0 else "RightBracket"))
	bracket.position.x = _layout[bracket].position.x + (54-face.get("bracket",0)) * (1 if side == 0 else -1)
	if face.is_empty(): return
	node.position = _layout[node].position + face.position - Vector2(31 if side == 0 else 237,30)
	node.scale = _layout[node].scale * Vector2(1,face.size.y/89.0)
	for index in 2:
		var image: TextureRect = node.get_node("Current" if index == 0 else "Previous")
		if state.get("images",[]).size() == 4: image.apply_image(state.images[side*2+index])
		var weight: float = face.previous_weight/128.0
		var intensity := 1-weight if index == 0 else weight
		image.self_modulate = _layout[image].self_modulate * Color(intensity,intensity,intensity,1)
	var scanline: Control = node.get_node("Scanline")
	scanline.position.y = _layout[scanline].position.y + face.scanline
	show_native(path+"/Scanline",face.scanline<face.size.y)

func apply_contacts(state: Dictionary) -> void:
	var enabled := bool(state.get("memory",false))
	show_native("Panel/Contacts",enabled)
	if not enabled: return
	var message: Dictionary = state.get("message",{})
	for index in 8:
		var path := "Panel/Contacts/Contact%d"%index
		var row: Control = get_node(path)
		row.position.y = _layout[row].position.y - (index/2)*state.get("memory_animation",0)*5
		var frequency: int = state.contacts[index]
		if row.has_node("FrequencyFraction"):
			get_node(path+"/Frequency").text = "%03d" % (frequency/100) if frequency else ""
			get_node(path+"/FrequencyFraction").text = "%02d" % (frequency%100) if frequency else ""
			show_native(path+"/FrequencyDot", frequency > 0)
		else:
			get_node(path+"/Frequency").text = "%03d.%02d" % [frequency/100,frequency%100] if frequency else ""
		show_native(path+"/Preview",false)
		var layout: Dictionary = message.get("layout",{}).duplicate(true)
		var glyphs: Array = []
		for glyph in layout.get("glyphs",[]):
			if glyph.position.x/96 == index%2 and glyph.position.y/12 == index/2:
				glyph.position -= Vector2i((index%2)*96,(index/2)*12+4)
				glyphs.append(glyph)
		layout.glyphs = glyphs
		var name_node: Control = get_node(path+"/Name")
		name_node.apply_native_state({"active":frequency>0,"visible":true,"position":Vector2.ZERO,"layout":layout if not layout.is_empty() and layout.has("palette") else {}})
		name_node.self_modulate = _layout[name_node].self_modulate * (2.0 if index+state.get("memory_top",0)==state.get("memory_selected",0) else 1.0)
	show_native("Panel/Contacts/Up",state.get("memory_top",0)>0)
	show_native("Panel/Contacts/Down",state.get("memory_top",0)+8<state.get("memory_count",0))

func update_preview() -> void:
	if not _bound: return
	apply_native_state({"active":true,"incoming":preview_mode==3,"frequency":14085,"signal":8,"exit_hint":preview_mode==1,
		"memory":preview_mode==2,"contacts":PackedInt32Array([14085,14096,14152,14180,0,0,0,0]),"memory_count":4})
	if preview_mode == 0:
		show_native("Panel/PreviewMessage",true)
	if preview_mode == 2:
		for index in 4: show_native("Panel/Contacts/Contact%d/Preview"%index,true)
	remember_applied()
