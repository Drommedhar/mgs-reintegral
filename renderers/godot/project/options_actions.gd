extends "res://native_menu_actions.gd"

const ACTIONS = {"select":1, "set":2, "activate":3, "back":4}
const ROWS = [1,2,3,4,5,6,8,10]

func _init() -> void:
	_label = "Options"
	_word_count = 8
	_errors = {3:"Options changed; select the action again.", 4:"Options is opening or closing.", 5:"This option or value is unavailable."}

func request(action: String, target: int = 0, value: int = 0) -> int:
	if not _can_request(): return 0
	var error := _validate(action,target,value)
	if not error.is_empty(): return _reject(error)
	return _enqueue([_current.epoch,_current.generation,_current.revision,ACTIONS[action],target,value])

func _validate(action: String, target: int, value: int) -> String:
	if not ACTIONS.has(action) or target < 0 or value < 0 or (action != "set" and value): return "Invalid Options action"
	var selected: int = _current.selection
	if selected in [0,11]: return _errors[4]
	if action == "back": return "" if target == 0 else "Back does not take a target"
	if selected == 7: return "Use Back to leave screen adjustment"
	if selected == 9:
		if action == "select" and target <= 2: return ""
		if action == "set" and target <= 1 and value <= (1 if target else 2): return ""
		return "Invalid controller option"
	if target not in ROWS or (target in [4,5] and not _current.vibration): return "Option unavailable"
	if action == "select": return ""
	if action == "activate" and target in [6,8,10]: return ""
	if action == "set" and target <= 5 and value <= 1:
		if target == 5 and value and _current.vibration != 1: return "Strong vibration is unavailable"
		return ""
	return "Invalid Options value"
