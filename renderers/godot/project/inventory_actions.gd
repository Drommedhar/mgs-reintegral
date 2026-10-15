extends "res://native_menu_actions.gd"

const ACTIONS = {"open":1,"select":2,"equip":3,"use":4,"close":5}
var pending: Dictionary = {}

func _init() -> void:
	_label="Inventory"
	_word_count=8
	_errors={3:"Inventory changed; choose again.",4:"Inventory is unavailable.",5:"This inventory action is unavailable."}

func exchange_view(data: PackedByteArray, context: Dictionary) -> Dictionary:
	if data.size()!=652 or data.decode_u32(4)!=context.get("epoch",-1): return {"error":"Inventory action extent or epoch mismatch"}
	var view := {"epoch":data.decode_u32(4)}
	var fields := ["generation","revision","active","mode","owned","open_mask","allowed","count","selection","item","weapon"]
	for index in fields.size(): view[fields[index]]=data.decode_s32(32+index*4) if index>=8 else data.decode_u32(32+index*4)
	if view.active>1 or view.mode>2 or view.owned>1 or view.open_mask & ~3 or view.allowed & ~60 or view.count>36:
		return {"error":"Invalid inventory action state"}
	if view.selection < -1 or view.selection > 23 or view.item < -1 or view.item > 23 or view.weapon < -1 or view.weapon > 9:
		return {"error":"Invalid inventory item identity"}
	if view.active and (not view.generation or not view.revision): return {"error":"Missing inventory action identity"}
	view.entries=[]
	for index in 36:
		var at := 76+index*16
		var entry := {"side":data.decode_u32(at),"id":data.decode_s32(at+4),"quantity":data.decode_s32(at+8),"flags":data.decode_u32(at+12)}
		if index>=view.count:
			if data.decode_u64(at) or data.decode_u64(at+8): return {"error":"Nonzero unused inventory entry"}
			continue
		if entry.side>1 or entry.id < -1 or entry.id>(23 if entry.side==0 else 9) or entry.flags & ~3:
			return {"error":"Invalid inventory entry"}
		view.entries.append(entry)
	var response: Dictionary = super.exchange(data.slice(0,32))
	if not response.has("error"): pending=view
	return response

func present_pending(epoch: int, visible: bool) -> void:
	present(pending if visible and pending.get("epoch",-1)==epoch else {})

func request(action: String, side: int, target: int = 0) -> int:
	if not _can_request(): return 0
	var error := validate(action,side,target)
	if not error.is_empty(): return _reject(error)
	return _enqueue([_current.epoch,_current.generation,_current.revision,ACTIONS[action],side,target])

func validate(action: String, side: int, target: int) -> String:
	if not ACTIONS.has(action) or side not in [0,1]: return "Invalid inventory action"
	if action=="open": return "" if not target and not _current.get("mode",0) and _current.get("open_mask",0) & (1<<side) else _errors[5]
	if _current.get("mode",0)!=side+1 or not _current.get("allowed",0) & (1<<ACTIONS[action]): return _errors[5]
	if action=="close": return "" if not target else "Close takes no item target"
	for entry in _current.get("entries",[]):
		if entry.side!=side or entry.id!=target: continue
		if action=="select" or (action=="equip" and entry.flags & 1): return ""
		if action=="use" and side==0 and target==_current.get("selection",-1) and entry.flags & 2: return ""
	return _errors[5]
