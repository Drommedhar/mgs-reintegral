extends "res://native_menu_actions.gd"

const ACTIONS = {"open":1,"tune":2,"call":3,"memory":4,"select":5,"confirm":6,"advance":7,"skip":8,"back":9}
const FIELDS = ["generation","revision","active","opened","mode","frequency","allowed","selection","count"]
var pending: Dictionary = {}

func exchange_view(data: PackedByteArray, context: Dictionary) -> Dictionary:
	if data.size()!=68 or data.decode_u32(4)!=context.get("epoch",-1): return {"error":"Codec action epoch mismatch"}
	return exchange(data)

func _init() -> void:
	_label = "Codec"
	_word_count = 7
	_errors = {3:"The Codec state changed; choose again.",4:"Codec is unavailable.",5:"This Codec action is unavailable."}

func exchange(data: PackedByteArray) -> Dictionary:
	if data.size()!=68: return {"error":"Invalid Codec action view size"}
	var view := {"epoch":data.decode_u32(4)}
	for index in FIELDS.size(): view[FIELDS[index]]=data.decode_u32(32+index*4)
	if view.active>1 or view.opened>1 or view.mode>21 or view.allowed & ~1022 or view.selection>32 or view.count>32:
		return {"error":"Invalid Codec action state"}
	if view.active and (not view.generation or not view.revision or view.frequency<14000 or view.frequency>14199):
		return {"error":"Invalid active Codec identity or frequency"}
	var response: Dictionary = super.exchange(data.slice(0,32))
	if not response.has("error"): pending=view
	return response

func present_pending(epoch: int, visible: bool) -> void:
	present(pending if visible and pending.get("epoch",-1)==epoch else {})

func request(action: String, target: int = 0) -> int:
	if not _can_request(): return 0
	var error := validate(action,target)
	if not error.is_empty(): return _reject(error)
	return _enqueue([_current.epoch,_current.generation,_current.revision,ACTIONS[action],target])

func validate(action: String, target: int) -> String:
	if not ACTIONS.has(action) or target<0: return "Invalid Codec action"
	if not _current.get("allowed",0) & (1<<ACTIONS[action]): return _errors[5]
	if action=="tune": return "" if target>=14000 and target<=14199 else "Frequency must be 140.00–141.99"
	if action in ["select","confirm"]: return "" if target<_current.get("count",0) else "Codec entry is unavailable"
	return "" if target==0 else "This Codec action takes no target"
