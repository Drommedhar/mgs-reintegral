extends RefCounted

var session_id := PackedByteArray()
var pending: Dictionary = {}
var current: Dictionary = {}

func apply(data: PackedByteArray, context: Dictionary) -> String:
	if data.size() < 68 or data.decode_u32(0) != 1: return "Invalid save UI header"
	if session_id.size() != 16 or data.slice(8,24) != session_id: return "Save UI session mismatch"
	var epoch := data.decode_u32(4)
	if epoch != context.get("epoch",-1): return "Save UI epoch mismatch"
	var next := {"epoch":epoch,"entries":[]}
	var keys := ["active","generation","revision","loading","state","message","count","selected_id","can_create","cursor","choice"]
	for index in keys.size(): next[keys[index]] = data.decode_u32(24+index*4)
	if next.active > 1 or next.loading > 1 or next.state > 4 or next.message > 11 or next.count > 30 or next.can_create > 1 or next.choice > 1 or next.cursor > next.count: return "Invalid save UI state"
	if data.size() != 68+next.count*96 or (next.active and not next.generation) or (next.loading and next.can_create): return "Invalid save UI extent"
	var identities := {}
	var fields := ["id","hours","minutes","disc","difficulty","completion","area","metadata_valid"]
	for index in next.count:
		var offset: int = 68+index*96
		var row := {}
		for field in fields.size(): row[fields[field]] = data.decode_u32(offset+field*4)
		var name := data.slice(offset+32,offset+96)
		var end := name.find(0)
		if end < 0 or row.id == 0 or identities.has(row.id) or row.metadata_valid > 1: return "Invalid save UI entry"
		for character in name.slice(0,end):
			if character < 32 or character > 126: return "Invalid save location encoding"
		if row.metadata_valid and (row.hours > 99 or row.minutes > 59 or row.disc not in [1,2] or row.difficulty > 4 or row.completion > 1 or row.area > 63): return "Invalid save metadata"
		row.location = name.slice(0,end).get_string_from_ascii()
		identities[row.id] = true
		next.entries.append(row)
	if next.selected_id and not identities.has(next.selected_id): return "Unknown selected save"
	pending = next
	return ""

func present(epoch: int) -> Dictionary:
	current = pending if pending.get("epoch",-1) == epoch else {}
	return current
