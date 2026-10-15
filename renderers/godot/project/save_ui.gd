@tool
extends Control

signal native_state_changed(state: Dictionary)
@export var preview_loading := false:
	set(value):
		preview_loading = value
		if Engine.is_editor_hint(): update_preview.call_deferred()
@export var selection_color := Color("2e483d")
var provider: Node
var _state: Dictionary = {}
var _cursor := 0
var _top := 0
var _focus_key := ""
var _error := ""

func connect_provider(value: Node) -> void:
	provider = value
	provider.state_changed.connect(_provider_changed)
	provider.action_finished.connect(_action_finished)
	for index in 6:
		var button: Button = get_node("SaveList/Save%d/Activate" % index)
		button.pressed.connect(_activate_row.bind(index))
		button.focus_entered.connect(_focus_row.bind(index))
	$NewSave/Activate.pressed.connect(_request.bind("new_save",0))
	$NewSave/Activate.focus_entered.connect(_focus_new)
	$Back.pressed.connect(_request.bind("back",0))
	$Dialog/Confirm.pressed.connect(_request.bind("confirm",0))
	$Dialog/Cancel.pressed.connect(_request.bind("back",0))
	$Dialog/Continue.pressed.connect(_request.bind("continue",0))

func _provider_changed(state: Dictionary) -> void:
	provider.capture_input(bool(state.get("active",false)) and provider.supported)
	_refresh_actions()

func _action_finished(_id: int, message: String) -> void:
	_error = message
	_refresh_actions()

func _request(action: String, target: int) -> void:
	if provider == null: return
	_error = "" if provider.request(action,target) else provider.last_error
	_refresh_actions()

func _activate_row(index: int) -> void:
	var entries: Array = _state.get("entries",[])
	if _top+index < entries.size(): _request("activate",entries[_top+index].id)

func _focus_row(index: int) -> void:
	_cursor = _top+index
	_render_rows()

func _focus_new() -> void:
	_cursor = _state.get("entries",[]).size()
	_render_rows()

func _input(event: InputEvent) -> void:
	if provider == null or not provider.captures_input() or not is_visible_in_tree(): return
	if event.is_action_pressed("ui_cancel"):
		if not provider.is_pending(): _request("back",0)
		get_viewport().set_input_as_handled()
	elif _state.get("state",1) == 0:
		var direction := int(event.is_action_pressed("ui_down"))-int(event.is_action_pressed("ui_up"))
		if event is InputEventMouseButton and event.pressed:
			direction = int(event.button_index==MOUSE_BUTTON_WHEEL_DOWN)-int(event.button_index==MOUSE_BUTTON_WHEEL_UP)
		if direction:
			if not provider.is_pending(): _move_cursor(direction)
			get_viewport().set_input_as_handled()

func _move_cursor(direction: int) -> void:
	var entries: Array = _state.get("entries",[])
	var count: int = entries.size()+int(_state.get("can_create",false))
	_cursor = clampi(_cursor+direction,0,maxi(0,count-1))
	_ensure_visible()
	_render_rows()
	_focus_selection()

func _ensure_visible() -> void:
	var count: int = _state.get("entries",[]).size()
	if _cursor < _top: _top = _cursor
	if _cursor >= _top+6: _top = _cursor-5
	_top = clampi(_top,0,maxi(0,count-6))

func _focus_selection() -> void:
	if _cursor == _state.get("entries",[]).size():
		if _state.get("can_create",false): $NewSave/Activate.grab_focus()
		else: $Back.grab_focus()
	else: get_node("SaveList/Save%d/Activate" % (_cursor-_top)).grab_focus()

func _refresh_actions() -> void:
	if not has_node("Back"): return
	var bound: bool = provider != null and provider.supported
	var captured: bool = bound and provider.captures_input()
	var ready: bool = captured and not provider.is_pending()
	var mode: int = _state.get("state",1)
	for index in 6: get_node("SaveList/Save%d/Activate"%index).disabled = not ready or mode != 0
	$NewSave/Activate.disabled = not ready or mode != 0 or not _state.get("can_create",false)
	$Back.visible = bound and mode == 0
	$Back.disabled = not ready
	$Dialog/Choices.visible = not bound and mode == 2
	for pair in [["Confirm",2],["Cancel",2],["Continue",4]]:
		var button: Button = get_node("Dialog/"+pair[0])
		button.visible = bound and mode == pair[1]
		button.disabled = not ready
	$Dialog/Confirm.text = "INITIALIZE" if _state.get("message",0)==1 else "OVERWRITE"
	$Error.text = _error
	$Error.visible = not _error.is_empty()
	$Count.visible = _error.is_empty()
	$Hint.text = "CONFIRM: SELECT   BACK: EXIT"
	if bound:
		$Hint.text = {0:"SELECT A SAVE   /   BACK: EXIT",2:"CONFIRM OR CANCEL",4:"CONTINUE"}.get(mode,"PLEASE WAIT")
	var key := "%d:%d:%d" % [int(_state.get("generation",0)),mode,int(ready)]
	if key == _focus_key: return
	_focus_key = key
	if not ready or not is_inside_tree(): return
	if mode == 0: _focus_selection()
	elif mode == 2: $Dialog/Cancel.grab_focus()
	elif mode == 4: $Dialog/Continue.grab_focus()

func bind_originals(resources: RefCounted) -> String:
	if theme != null and (theme.default_font == null or theme.default_font.has_meta("mgs_retail_derived")):
		theme.default_font = resources.font("mgs/ui/menu_small")
		if theme.default_font == null: return resources.error
	for node in find_children("*","Control",true,false):
		if not node.has_meta("mgs_ui_font"): continue
		if node.has_theme_font_override("font") and not node.get_theme_font("font").get_meta("mgs_retail_derived",false): continue
		var font: FontFile = resources.font(node.get_meta("mgs_ui_font"))
		if font == null: return resources.error
		node.add_theme_font_override("font",font)
	return ""

func detach_originals() -> void:
	if theme != null and theme.default_font != null and theme.default_font.has_meta("mgs_retail_derived"):
		theme.default_font = null
	for node in find_children("*","Control",true,false):
		if node.has_theme_font_override("font") and node.get_theme_font("font").get_meta("mgs_retail_derived",false):
			node.remove_theme_font_override("font")

func apply_native_state(state: Dictionary) -> void:
	if not has_node("Title"): return
	if state.get("generation",0) != _state.get("generation",0) or provider == null or not provider.supported:
		_cursor = state.get("cursor",0)
		_error = ""
	_state = state.duplicate(true)
	_cursor = clampi(_cursor,0,maxi(0,state.get("entries",[]).size()+int(state.get("can_create",false))-1))
	_ensure_visible()
	var loading: bool = state.get("loading",false)
	$Title.text = "LOAD DATA" if loading else "SAVE DATA"
	var entries: Array = state.get("entries",[])
	_render_rows()
	$Empty.visible = entries.is_empty()
	$Empty.text = "No saved games"
	$NewSave.visible = not loading
	$NewSave/Label.text = "NEW SAVE" if state.get("can_create",false) else "No room for another save"
	$Count.text = "%d saved game%s" % [entries.size(),"" if entries.size()==1 else "s"]
	var mode: int = state.get("state",1)
	$Dialog.visible = mode != 0
	$Dialog/Choices.text = "[ OVERWRITE ]     Cancel" if state.get("choice",1)==0 else "Overwrite     [ CANCEL ]"
	var message: int = state.get("message",0)
	$Dialog/Message.text = message_text(mode,message,loading)
	if mode == 2 and message == 1:
		$Dialog/Choices.text = "[ INITIALIZE ]     Cancel" if state.get("choice",1)==0 else "Initialize     [ CANCEL ]"
	_refresh_actions()
	native_state_changed.emit(state.duplicate(true))

func _render_rows() -> void:
	var entries: Array = _state.get("entries",[])
	for index in 6:
		var node := get_node("SaveList/Save%d" % index) as Control
		var row := _top+index
		node.visible = row < entries.size()
		if not node.visible: continue
		var entry: Dictionary = entries[row]
		(node.get_node("Selection") as ColorRect).color = selection_color
		node.get_node("Selection").visible = row == _cursor
		node.get_node("Location").text = entry.location if entry.metadata_valid else "Unreadable save information"
		node.get_node("Details").text = details(entry)
	$NewSave/Selection.color = selection_color
	$NewSave/Selection.visible = _cursor == entries.size() and _state.get("can_create",false)

func details(entry: Dictionary) -> String:
	if not entry.metadata_valid: return "Native save validation required"
	var difficulty: String = ["Very Easy","Easy","Normal","Hard","Extreme"][entry.difficulty]
	var time := "Completed" if entry.completion else "%02d:%02d" % [entry.hours,entry.minutes]
	return "%s   /   %s" % [time,difficulty]

func message_text(mode: int, message: int, loading: bool) -> String:
	if mode == 0: return ""
	if mode == 2: return "Initialize save storage?" if message == 1 else "Overwrite this saved game?"
	if mode == 3: return "Loading..." if loading else "Saving..."
	if mode == 1: return "Checking saved games..."
	match message:
		1,6: return "Game loaded." if loading else "Game saved."
		2: return "Unable to load this save." if loading else "Unable to save the game."
		3: return "Save storage error. Please try again."
		4: return "No saved games." if loading else "No room for another save."
		5: return "Save storage is not initialized."
		7: return "Unable to initialize save storage."
		8: return "Save storage is unavailable."
	return "Please continue."

func update_preview() -> void:
	apply_native_state({"active":true,"loading":preview_loading,"state":0,"cursor":0,"can_create":not preview_loading,
		"entries":[{"id":1,"location":"Dock","hours":1,"minutes":24,"difficulty":2,"completion":0,"metadata_valid":1},
		{"id":2,"location":"Heliport","hours":2,"minutes":8,"difficulty":2,"completion":0,"metadata_valid":1}]})
