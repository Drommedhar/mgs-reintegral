extends "res://native_menu_actions.gd"

const ACTIONS = {"select":1, "activate":2, "back":3}
const MODES = [0,1,4,5,6,7,18,19,21]

func _init() -> void:
	_label = "Title"
	_word_count = 7
	_errors = {3:"The title menu changed; choose again.", 4:"The title menu is transitioning.", 5:"This title action is unavailable."}

func request(action: String, target: int = 0) -> int:
	if not _can_request(): return 0
	var error := validate(action,target)
	if not error.is_empty(): return _reject(error)
	return _enqueue([_current.epoch,_current.generation,_current.revision,ACTIONS[action],target])

func validate(action: String, target: int) -> String:
	if not ACTIONS.has(action) or target < 0: return "Invalid title action"
	if not _current.get("revision",0): return _errors[4]
	var mode: int = _current.get("mode",0)
	if mode not in MODES: return _errors[5]
	if mode in [0,1,4,5,6]: return "" if action == "activate" and target == 0 else _errors[5]
	if action == "back": return "" if target == 0 else _errors[5]
	var limit := 4 if mode == 7 else (4 if _current.get("extreme",false) else 3) if mode == 21 else 1
	return "" if target <= limit else _errors[5]
