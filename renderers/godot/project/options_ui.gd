@tool
extends Control

const Layout = preload("options_layout.gd")
signal native_state_changed(state: Dictionary)
@export_enum("Options", "Screen adjustment", "Controller") var preview_page := 0:
	set(value):
		preview_page = value
		if Engine.is_editor_hint(): update_preview.call_deferred()
@export_range(1,10) var preview_selection := 1:
	set(value):
		preview_selection = value
		if Engine.is_editor_hint(): update_preview.call_deferred()
var _textures := {}
var _blends := {}
var _elements: Array[Control] = []
var _texts: Array[Control] = []
var provider: Node
var _buttons: Array[Button] = []
var _state: Dictionary = {}
var _focus_key := ""
var _error := ""
var _pages: Dictionary = {}
var _page_request := 0
var _requested_page: Control
var _page_font: Font

func connect_provider(value: Node) -> void:
	provider = value
	provider.state_changed.connect(_provider_changed)
	provider.action_finished.connect(_action_finished)
	for node in find_children("*","Button",true,false):
		if "native_action" not in node: continue
		_buttons.append(node)
		node.pressed.connect(_request.bind(node.native_action,node.native_option,node.native_value))

func register_page(option: int, label: String, page: Control) -> String:
	if _pages.has(option): return "Options row %d already has a page" % option
	for button in _buttons:
		if button.native_action != "activate" or button.native_option != option: continue
		_pages[option] = page
		if button.text.is_empty(): button.text = label
		button.add_theme_font_size_override("font_size",8)
		button.add_theme_color_override("font_color",Color(100.0/128,160.0/128,135.0/128))
		for state in ["font_focus_color","font_hover_color","font_pressed_color"]:
			button.add_theme_color_override(state,Color(1.5,1.5,1.5))
		if _page_font != null: button.add_theme_font_override("font",_page_font)
		button.get_parent().self_modulate.a = 0
		return ""
	return "Options row %d needs an editable activate Button" % option

func _provider_changed(state: Dictionary) -> void:
	_state = state
	provider.capture_input(bool(state.get("active",false)) and provider.supported)
	_refresh_actions()

func _action_finished(id: int, error: String) -> void:
	_error = error
	_refresh_actions()
	if id == _page_request:
		_page_request = 0
		if error.is_empty() and is_instance_valid(_requested_page): _requested_page.open_menu()
		_requested_page = null

func _request(action: String, option: int = 0, value: int = 0) -> void:
	if provider == null: return
	if action == "activate" and _pages.has(option):
		_page_request = provider.request("select",option)
		_requested_page = _pages[option] if _page_request else null
		_error = "" if _page_request else provider.last_error
	else:
		_error = "" if provider.request(action,option,value) else provider.last_error
	_refresh_actions()

func _refresh_actions() -> void:
	var message := get_node_or_null("ActionError") as Label
	if message != null:
		message.text = _error
		message.tooltip_text = _error
		message.visible = not _error.is_empty()
	var selected: int = _state.get("selection",0)
	for page in _pages.values(): page.allow_options(bool(_state.get("active",false)) and selected in [1,2,3,4,5,6,8,10])
	var enabled: bool = provider.captures_input() and not provider.is_pending() and selected not in [0,11]
	for button in _buttons: button.disabled = not enabled
	var key := "%d:%d" % [selected,_state.get("controller_row",0)]
	if not enabled:
		_focus_key = ""
		return
	if key == _focus_key: return
	_focus_key = key
	var paths := {1:"Options/Captions",2:"Options/Language",3:"Options/Sound",4:"Options/Vibration",
		5:"Options/VibrationTest",6:"Options/Screen",7:"ScreenAdjustment/ScreenExit",8:"Options/Controller",10:"Options/Exit"}
	var path: String = paths.get(selected,"")
	if selected == 9: path = "Controller/"+["ButtonMapping","FirstPerson","ControllerExit"][_state.controller_row]
	var button := get_node_or_null(path+"/Interact") as Button
	if button != null and button.is_visible_in_tree(): button.grab_focus()

func _input(event: InputEvent) -> void:
	if provider == null or not provider.captures_input() or not is_visible_in_tree(): return
	for action in ["ui_cancel","ui_up","ui_down","ui_left","ui_right","ui_accept"]:
		if not event.is_action_pressed(action): continue
		if action == "ui_accept":
			var focused := get_viewport().gui_get_focus_owner()
			if focused == null or not is_ancestor_of(focused) or "native_action" not in focused: return
		get_viewport().set_input_as_handled()
		if not provider.is_pending() and _state.get("selection",0) not in [0,11]: _navigate(action)
		return

func _navigate(action: String) -> void:
	var selected: int = _state.selection
	if action == "ui_accept":
		_accept()
		return
	if action == "ui_cancel":
		_request("back")
		return
	if action in ["ui_up","ui_down"]:
		var direction := 1 if action == "ui_down" else -1
		if selected == 9: _request("select",clampi(_state.controller_row+direction,0,2))
		elif selected != 7:
			var rows := [1,2,3,4,5,6,8,10] if _state.vibration else [1,2,3,6,8,10]
			_request("select",rows[clampi(rows.find(selected)+direction,0,rows.size()-1)])
		return
	if selected == 9: _controller_value(action)
	elif selected <= 5:
		var value: int = 0 if action == "ui_left" else 1
		if selected == 5 and _state.vibration == 2: value=0
		_request("set",selected,value)

func _accept() -> void:
	var button := get_viewport().gui_get_focus_owner() as Button
	if button == null or button.disabled: return
	if button.native_action != "select":
		button.pressed.emit()
		return
	var target: int = button.native_option
	if _state.selection == 9:
		if target in [0,1]:
			var value: int = (_state.controller_type+1)%3 if target==0 else 1-_state.reverse
			_request("set",target,value)
		elif target==2: _request("back")
		else: _request("select",target)
	elif target in [1,2,3,4,5]:
		var value: int = 1-_state.values[target]
		if target == 5 and _state.vibration == 2: value=0
		_request("set",target,value)
	else: _request("activate",target)

func _controller_value(action: String) -> void:
	var row: int = _state.controller_row
	if row == 2: return
	var value: int = _state.controller_type if row == 0 else _state.reverse
	var limit := 2 if row == 0 else 1
	value = clampi(value+(-1 if action == "ui_left" else 1),0,limit)
	_request("set",row,value)

func bind_originals(resources: RefCounted) -> String:
	resources.bind_dialogue_fonts(self)
	_page_font = resources.font("mgs/ui/menu_large")
	if _page_font == null: return resources.error
	for button in _buttons:
		if _pages.has(button.native_option) and button.native_action == "activate": button.add_theme_font_override("font",_page_font)
	var message := get_node_or_null("ActionError") as Label
	if message != null:
		var font: Font = resources.font("mgs/ui/menu_small")
		if font == null: return resources.error
		message.add_theme_font_override("font",font)
	_textures.clear()
	for name in Layout.TEXTURES:
		var identity: int = Layout.texture_id(name)
		var source := "mgs/integral-j/disc%d/stage/option/%04x.p" % [resources.disc,identity]
		var texture: Texture2D = resources.texture(source)
		if texture == null: return resources.error
		_textures[identity] = texture
		_blends[identity] = 1 + int(resources.assets[source].abr)
	_elements.clear()
	_texts.clear()
	for node in find_children("*","Control",true,false):
		if node.has_method("apply_element"):
			node.remember()
			_elements.append(node)
		elif node.has_meta("mgs_options_text"):
			_texts.append(node)
	return ""

func apply_native_state(state: Dictionary) -> void:
	if _textures.is_empty(): return
	var elements: Array = state.get("elements",[])
	for node in _elements:
		var element: Dictionary = elements[node.native_element] if node.native_element < elements.size() else {}
		node.apply_element(element,_textures)
	for node in _texts:
		node.apply_native_state(state.get("texts",{}).get(int(node.get_meta("mgs_options_text")),{}))
	native_state_changed.emit(state.duplicate(true))

func detach_originals() -> void:
	_page_font = null
	for button in _buttons:
		if button.has_theme_font_override("font") and button.get_theme_font("font").has_meta("mgs_retail_derived"): button.remove_theme_font_override("font")
	var message := get_node_or_null("ActionError") as Label
	if message != null: message.remove_theme_font_override("font")
	for node in _elements: node.detach_originals()
	for node in _texts: node.detach_originals()
	_elements.clear()
	_texts.clear()
	_textures.clear()
	_blends.clear()

func update_preview() -> void:
	if _textures.is_empty(): return
	var elements: Array[Dictionary] = []
	for index in Layout.ELEMENTS.size():
		var item: Array = Layout.ELEMENTS[index]
		var identity: int = Layout.texture_id(item[1])
		var layer := 3 if index in [21,22,27,28,31,32] else 1
		if (preview_page == 0 and index > 26) or (preview_page == 1 and index not in range(27,31)) or (preview_page == 2 and index not in range(31,48)): layer = 0
		if index == 20: layer = 0
		elements.append({"texture":identity,"position":item[2].position,"size":item[2].size,
			"rgb":0x87a064 if index not in [21,22,27,28,31,32,39,40] else 0x808080,"layer":layer,"blend":_blends[identity] if item[3] else 0})
	var selected: int = {1:2,2:23,3:3,4:4,5:5,6:6,8:7,10:8}.get(preview_selection,2)
	if preview_page == 0:
		elements[selected].rgb = 0xc7e0bc
		var focus := Layout.focus_rects(Layout.ELEMENTS[selected][2])
		for index in focus.size():
			elements[48+index].merge({"position":focus[index].position,"size":focus[index].size,"rgb":0xffffff,"layer":2},true)
	apply_native_state({"active":true,"elements":elements,"texts":{}})
