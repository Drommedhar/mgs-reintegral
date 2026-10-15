@tool
extends RefCounted

const Catalog = preload("res://addons/mgs_editor/scene_catalog.gd")

static func key(entry: Dictionary) -> String:
	return entry.stage + ":" + entry.get("clip", "")

static func priority(entry: Dictionary, preferred: int) -> int:
	var score := 100 if entry.reason.is_empty() else 0
	if entry.get("edited", false): score += 10
	if int(entry.source.disc) == preferred: score += 1
	return score

static func entries(catalogs: Dictionary, root_path: String, manifest: Dictionary, preferred: int) -> Array[Dictionary]:
	var combined := {}
	for disc in catalogs:
		var prepared: Dictionary = catalogs[disc]
		var edits := Catalog.modifications(prepared, manifest)
		var listed := prepared.duplicate()
		listed.maps = prepared.get("maps", {}).duplicate()
		for target in manifest.get("stages", {}):
			if Catalog.Registry.target_disc(target) not in [0, int(disc)]: continue
			var stage := Catalog.Registry.target_stage(target)
			if not listed.maps.has(stage): listed.maps[stage] = {}
		for entry in Catalog.entries(listed, root_path):
			if entry.kind in ["UI", "Shared assets"]: continue
			entry.edited = edits.has(entry.stage)
			entry.edit_label = Catalog.edit_label(entry.stage, edits.get(entry.stage, {})).replace("\n", ", ")
			var identity := key(entry)
			if not combined.has(identity) or priority(entry, preferred) > priority(combined[identity], preferred):
				combined[identity] = entry
	var result: Array[Dictionary] = []
	result.assign(combined.values())
	result.sort_custom(func(a, b): return a.location.naturalnocasecmp_to(b.location) < 0 if a.location != b.location else key(a) < key(b))
	return result
