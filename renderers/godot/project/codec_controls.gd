extends RefCounted

var ui: Control
var provider: Node
var buttons: Array[Button] = []
var state: Dictionary = {}
var artwork: Dictionary = {}
var error := ""

func connect_provider(root: Control, value: Node) -> void:
	ui=root
	provider=value
	provider.state_changed.connect(_changed)
	provider.action_finished.connect(_finished)
	for node in ui.find_children("*","Button",true,false):
		if "native_action" not in node: continue
		buttons.append(node)
		node.pressed.connect(_request.bind(node.native_action,node.native_target))

func _changed(value: Dictionary) -> void:
	state=value
	provider.capture_input(provider.supported and state.get("active",false) and state.get("opened",false) and state.get("mode",0) not in [12,14])
	refresh()

func _finished(_id: int, message: String) -> void:
	error=message
	refresh()

func command(action: String, target: int) -> Array:
	if action=="tune_step": return ["tune",14000+posmod(state.get("frequency",14000)-14000+target,200)]
	if action=="contact": return ["confirm",artwork.get("memory_top",0)+target]
	if action=="confirm" and target==-1: return [action,state.get("selection",0)]
	return [action,target]

func _request(action: String, target: int = 0) -> void:
	var request := command(action,target)
	error="" if provider.request(request[0],request[1]) else provider.last_error
	refresh()

func refresh() -> void:
	if provider==null: return
	for button in buttons:
		var request := command(button.native_action,button.native_target)
		button.visible=provider.supported and state.get("active",false) and provider.validate(request[0],request[1]).is_empty()
		button.disabled=provider.is_pending() or (not provider.captures_input() and request[0]!="open")
	var label := ui.get_node_or_null("ActionError") as Label
	if label!=null:
		label.text=error
		label.visible=not error.is_empty() and state.get("opened",false)

func input(event: InputEvent) -> void:
	if provider==null or not provider.captures_input() or not ui.is_visible_in_tree(): return
	for action in ["ui_cancel","ui_up","ui_down","ui_left","ui_right","ui_accept"]:
		if not event.is_action_pressed(action): continue
		ui.get_viewport().set_input_as_handled()
		if not provider.is_pending(): navigate(action)
		return

func navigate(action: String) -> void:
	if action=="ui_accept":
		var focused := ui.get_viewport().gui_get_focus_owner() as Button
		if focused!=null and ui.is_ancestor_of(focused) and not focused.disabled and "native_action" in focused:
			focused.pressed.emit()
			return
	var mode: int = state.get("mode",0)
	if mode==1:
		if action=="ui_cancel": _request("back")
		elif action=="ui_down": _request("memory")
		elif action in ["ui_up","ui_accept"]: _request("call")
		else: _request("tune_step",-1 if action=="ui_left" else 1)
	elif mode in [10,16]:
		if action=="ui_accept": _request("confirm",state.get("selection",0))
		elif action=="ui_cancel" and mode==10: _request("back")
		elif action in ["ui_up","ui_down","ui_left","ui_right"]:
			var delta := (-1 if action in ["ui_left","ui_up"] else 1)*(2 if mode==10 and action in ["ui_up","ui_down"] else 1)
			_request("select",clampi(state.get("selection",0)+delta,0,maxi(0,state.get("count",0)-1)))
	elif mode in [4,9] and action in ["ui_accept","ui_cancel"]: _request("advance")
	elif mode==5 and action=="ui_cancel": _request("skip")
