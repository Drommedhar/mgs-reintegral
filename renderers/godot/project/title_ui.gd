@tool
extends Control

const Layout = preload("title_layout.gd")
signal native_state_changed(state: Dictionary)
@export_enum("Press Start", "Main menu", "Difficulty", "Special") var preview_page := 0:
	set(value):
		preview_page = value
		if Engine.is_editor_hint(): update_preview.call_deferred()
@export_range(0,4) var preview_difficulty := 2:
	set(value):
		preview_difficulty = value
		if Engine.is_editor_hint(): update_preview.call_deferred()
var _textures := {}
var _blends := {}
var _elements: Array[Control] = []
var _texts: Array[Control] = []
var _labels: Dictionary = {}
var _label_applied: Dictionary = {}
var _groups: Dictionary = {}

var provider: Node
var _buttons: Array[Button] = []
var _state: Dictionary = {}
var _focus_key := ""
var _error := ""

func connect_provider(value: Node) -> void:
	provider = value
	provider.state_changed.connect(_provider_changed)
	provider.action_finished.connect(_action_finished)
	for node in find_children("*","Button",true,false):
		if "native_action" not in node: continue
		_buttons.append(node)
		node.pressed.connect(_request.bind(node.native_action,node.native_target))

func _provider_changed(state: Dictionary) -> void:
	_state = state
	var mode: int = state.get("mode",0)
	provider.capture_input(bool(state.get("active",false)) and provider.supported and mode in [0,1,4,5,6,7,18,19,21])
	_refresh_actions()

func _action_finished(_id: int, error: String) -> void:
	_error = error
	_refresh_actions()

func _request(action: String, target: int = 0) -> void:
	if provider == null: return
	_error = "" if provider.request(action,target) else provider.last_error
	_refresh_actions()

func _refresh_actions() -> void:
	var message := get_node_or_null("ActionError") as Label
	if message != null:
		message.text = _error
		message.tooltip_text = _error
		message.visible = not _error.is_empty()
	var mode: int = _state.get("mode",0)
	var page := 1 if mode in [0,1] else 6 if mode in [4,5,6] else 18 if mode == 19 else mode
	var selected: int = _state.get("difficulty",2) if mode == 21 else _state.get("storage_choice",0) if page == 18 else _state.get("selection",0) if mode == 7 else 0
	var enabled: bool = provider.captures_input() and not provider.is_pending() and _state.get("revision",0) != 0
	var key := "%d:%d" % [page,selected] if enabled else ""
	for button in _buttons:
		button.visible = button.native_page == page or (button.native_page == 0 and page in [7,18,21])
		button.disabled = not enabled or not provider.validate(button.native_action,button.native_target).is_empty()
		if key != _focus_key and enabled and button.native_page == page and button.native_target == selected and button.is_visible_in_tree(): button.grab_focus()
	_focus_key = key

func _input(event: InputEvent) -> void:
	if provider == null or not provider.captures_input() or not is_visible_in_tree(): return
	for action in ["mgs_start","ui_cancel","ui_up","ui_down","ui_left","ui_right","ui_accept"]:
		if not event.is_action_pressed(action): continue
		if action in ["ui_accept","mgs_start"]:
			var focused := get_viewport().gui_get_focus_owner()
			if focused == null or not is_ancestor_of(focused) or "native_action" not in focused: return
		get_viewport().set_input_as_handled()
		if not provider.is_pending() and _state.get("revision",0): _navigate(action)
		return

func _navigate(action: String) -> void:
	var mode: int = _state.mode
	if action == "mgs_start":
		if mode not in [0,1,4,5,6,7]: return
		action = "ui_accept"
	elif mode in [4,5,6]: return
	if action == "ui_accept":
		var button := get_viewport().gui_get_focus_owner() as Button
		if button != null and not button.disabled: button.pressed.emit()
		return
	if action == "ui_cancel":
		if mode in [7,18,19,21]: _request("back")
		return
	var direction := 1 if action in ["ui_down","ui_right"] else -1
	if mode == 7 and action in ["ui_up","ui_down"]: _request("select",posmod(_state.selection+direction,5))
	elif mode == 21 and action in ["ui_up","ui_down"]: _request("select",clampi(_state.difficulty+direction,0,4 if _state.extreme else 3))
	elif mode in [18,19] and action in ["ui_left","ui_right"]: _request("select",1 if direction>0 else 0)

func bind_originals(resources: RefCounted) -> String:
	resources.bind_dialogue_fonts(self)
	_textures.clear()
	for name in Layout.TEXTURES:
		var identity: int = Layout.texture_id(name)
		var source := "mgs/integral-j/disc%d/stage/title/%04x.p" % [resources.disc,identity]
		var texture: Texture2D = resources.texture(source)
		if texture == null: return resources.error
		_textures[identity] = texture
		_blends[identity] = 1 + int(resources.assets[source].abr)
	var font: Font = resources.font("mgs/ui/menu_large")
	if font == null: return resources.error
	_elements.clear()
	_texts.clear()
	for node in find_children("*", "Control", true, false):
		if node.has_method("apply_element"):
			node.remember()
			_elements.append(node)
		elif node.has_meta("mgs_title_text"):
			_texts.append(node)
		elif node is Label:
			if not _labels.has(node): _labels[node] = node.self_modulate
			if not node.has_theme_font_override("font") or node.get_theme_font("font").has_meta("mgs_retail_derived"):
				node.add_theme_font_override("font", font)
	for path in ["Difficulty", "StorageWarning"]:
		if not _groups.has(path): _groups[path] = get_node(path).visible
	_label_applied = _labels.duplicate()
	return ""

func remember_label_edits() -> void:
	for node in _labels:
		if node.self_modulate != _label_applied.get(node,node.self_modulate): _labels[node] = node.self_modulate

func apply_native_state(state: Dictionary) -> void:
	if _textures.is_empty(): return
	remember_label_edits()
	var elements: Array = state.get("elements", [])
	for node in _elements:
		node.apply_element(elements[node.native_element] if node.native_element < elements.size() else {}, _textures)
	for node in _texts:
		node.apply_native_state(state.get("texts", {}).get(int(node.get_meta("mgs_title_text")), {}))
	get_node("Difficulty").visible = _groups.Difficulty and state.get("mode", 0) == 21
	get_node("StorageWarning").visible = _groups.StorageWarning and state.get("mode", 0) in [18,19]
	for path in ["Slot0","Slot1","Question","QuestionEnd"]:
		var node := get_node("StorageWarning/"+path) as Label
		node.self_modulate = _labels[node]*Color(100.0/128,160.0/128,135.0/128)
	for index in 2:
		var node := get_node("StorageWarning/Status%d"%index) as Label
		node.text = "   FULL" if state.get("storage_a" if index==0 else "storage_b",0)==3 else "NO CARD"
		node.self_modulate = _labels[node]*Color(181.0/128,85.0/128,42.0/128)
	for index in 5:
		var node: Label = get_node("Difficulty/Level%d" % index)
		var tint := Color8(192,192,192) if index == state.get("difficulty",2) else Color8(100,160,135)
		if index == 4 and not state.get("extreme",false): tint = Color8(64,64,64)
		node.self_modulate = _labels[node] * tint * Color(255.0/128.0,255.0/128.0,255.0/128.0,1)
	for index in 2:
		var node: Label = get_node("StorageWarning/" + ("Continue" if index == 0 else "Cancel"))
		node.self_modulate = _labels[node] * (Color(1.5,1.5,1.5) if index == state.get("storage_choice",0) else Color(46.0/128,72.0/128,61.0/128))
	for node in _labels: _label_applied[node] = node.self_modulate
	native_state_changed.emit(state.duplicate(true))

func detach_originals() -> void:
	remember_label_edits()
	for path in _groups: get_node(path).visible = _groups[path]
	for node in _elements: node.detach_originals()
	for node in _texts: node.detach_originals()
	for node in _labels:
		node.self_modulate = _labels[node]
		if node.has_theme_font_override("font") and node.get_theme_font("font").has_meta("mgs_retail_derived"): node.remove_theme_font_override("font")
	_elements.clear()
	_texts.clear()
	_labels.clear()
	_label_applied.clear()
	_groups.clear()
	_textures.clear()
	_blends.clear()

func update_preview() -> void:
	if _textures.is_empty(): return
	var elements: Array[Dictionary] = []
	for index in Layout.ELEMENTS.size():
		var item: Array = Layout.ELEMENTS[index]
		var identity: int = Layout.texture_id(item[1])
		var layer := 0
		if preview_page in [0,1] and index in [0,1,7,8,9,10,11]: layer = 7 if index < 2 else 1 if index in [7,8] else 2 if index == 10 else 3 if index == 9 else 4
		if preview_page == 0 and index == 12: layer = 1
		if preview_page == 1 and index in [49,50,51]: layer = 1
		if preview_page == 2 and index in [22,23,16]: layer = 3 if index != 16 else 1
		if preview_page == 3 and index in range(22,34): layer = 7 if index < 24 else 1
		var position: Vector2 = item[2].position
		if preview_page == 1 and index in [49,50,51]: position.y += (index-49)*14-14
		elements.append({"texture":identity,"position":position,"size":item[2].size,"source":Rect2(Vector2.ZERO,_textures[identity].get_size()),
			"top_rgb":0x87a064 if index == 16 else 0x808080,"bottom_rgb":0x87a064 if index == 16 else 0x808080,"layer":layer,"blend":_blends[identity] if item[3] else 0})
	if preview_page == 2:
		var x: int = [120,140,132,140,128][preview_difficulty]
		var y := 58+26*preview_difficulty
		var w: int = [82,42,58,42,66][preview_difficulty]
		var rects := [Rect2(x-6,y-6,8,8),Rect2(x+w-2,y-6,8,8),Rect2(x-6,y+3,8,8),Rect2(x+w-2,y+3,8,8),Rect2(x+2,y-6,w-4,8),Rect2(x+2,y+3,w-4,8),Rect2(x-6,y+2,8,5),Rect2(x+w-2,y+2,8,5),Rect2(x+2,y+2,w-4,5)]
		for index in 9: elements[40+index].merge({"position":rects[index].position,"size":rects[index].size,"layer":1,"top_rgb":0xffffff,"bottom_rgb":0xffffff},true)
	apply_native_state({"active":true,"mode":21 if preview_page==2 else 13 if preview_page==3 else 6+preview_page,"difficulty":preview_difficulty,"extreme":true,"elements":elements})
