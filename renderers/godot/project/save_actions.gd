extends "res://native_menu_actions.gd"

const ACTIONS = {"select":1, "activate":2, "new_save":3, "confirm":4, "back":5, "continue":6}

func _init() -> void:
	_label = "Save"
	_word_count = 10
	_errors = {3:"Save dialog changed; select the action again.", 4:"Save operation is busy.", 5:"This action is unavailable for the selected save."}

func request(action: String, target_id: int = 0) -> int:
	if not _can_request(): return 0
	if not ACTIONS.has(action) or target_id < 0 or target_id > 0xffffffff: return _reject("Invalid save action or target")
	var mode: int = _current.state
	if mode in [1,3]: return _reject("Save operation is busy.")
	if action in ["select", "activate", "new_save"]:
		if mode != 0: return _reject("Select a save from the list first")
		if action == "new_save" and target_id: return _reject("New Save does not take a target")
		if target_id:
			if not _current.entries.any(func(entry):return entry.id == target_id): return _reject("Unknown save ID")
		elif action == "activate" or not _current.can_create: return _reject("New Save is unavailable")
	else:
		if target_id: return _reject("This action does not take a target")
		if action == "confirm" and mode != 2: return _reject("No native confirmation is open")
		if action == "continue" and mode != 4: return _reject("No native result is open")
	return _enqueue([_current.epoch,_current.generation,_current.revision,
		_current.state,_current.message,_current.selected_id,ACTIONS[action],target_id])
