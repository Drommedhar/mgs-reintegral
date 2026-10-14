extends RefCounted

var ui: Control
var provider: Node
var buttons: Array[Button] = []
var state: Dictionary = {}
var error := ""

func connect_provider(root: Control, value: Node) -> void:
	ui=root
	provider=value
	provider.state_changed.connect(_changed)
	provider.action_finished.connect(_finished)
	for node in ui.find_children("*","Button",true,false): connect_button(node)

func connect_button(button: Button) -> void:
	if "native_action" not in button or button in buttons: return
	buttons.append(button)
	button.pressed.connect(_request_button.bind(button))

func _changed(value: Dictionary) -> void:
	state=value
	provider.capture_input(provider.supported and state.get("active",false) and state.get("owned",false))
	refresh()

func _finished(_id: int, message: String) -> void:
	error=message
	refresh()

func command(button: Button) -> Array:
	var side: int = button.native_side if button.native_side>=0 else state.get("mode",0)-1
	var target: int = state.get("selection",-1) if button.native_target==-2 else button.native_target
	return [button.native_action,side,target]

func _request_button(button: Button) -> void:
	var action := command(button)
	request(action[0],action[1],action[2])

func request(action: String, side: int, target: int) -> void:
	error="" if provider.request(action,side,target) else provider.last_error
	refresh()

func refresh() -> void:
	if provider==null: return
	for button in buttons:
		if not is_instance_valid(button): continue
		var action := command(button)
		var available: bool = provider.supported and state.get("active",false) and provider.validate(action[0],action[1],action[2]).is_empty()
		button.disabled=provider.is_pending() or not available
		if action[0] in ["open","select"]: button.visible=available

func input(event: InputEvent) -> void:
	if provider==null or not provider.captures_input() or not ui.is_visible_in_tree(): return
	for action in ["ui_cancel","ui_accept","ui_left","ui_right","ui_up","ui_down"]:
		if not event.is_action_pressed(action): continue
		ui.get_viewport().set_input_as_handled()
		if not provider.is_pending(): navigate(action)
		return

func navigate(action: String) -> void:
	var side: int = state.get("mode",0)-1
	if action=="ui_cancel": request("close",side,0)
	elif action=="ui_accept":
		var focus := ui.get_viewport().gui_get_focus_owner() as Button
		if focus!=null and ui.is_ancestor_of(focus) and not focus.disabled and "native_action" in focus: focus.pressed.emit()
		else: request("use" if provider.validate("use",side,state.selection).is_empty() else "equip",side,state.selection)
	else:
		var ids: Array = []
		for entry in state.get("entries",[]):
			if entry.side==side and entry.id not in ids: ids.append(entry.id)
		if ids.is_empty(): return
		var direction := -1 if action in ["ui_up","ui_left"] else 1
		request("select",side,ids[posmod(ids.find(state.selection)+direction,ids.size())])
