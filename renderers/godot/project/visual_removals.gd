@tool
extends RefCounted

const ModRegistry = preload("res://mod_registry.gd")

var rules: Array = []
var matches: Dictionary = {}

static func anchor(node: Node3D) -> Vector3:
	for skeleton in node.find_children("*", "Skeleton3D", true, false):
		var bone: int = skeleton.find_bone("part_000")
		if bone >= 0: return skeleton.transform * skeleton.get_bone_global_pose(bone).origin
	return node.position

func configure(overlay: Node3D, catalog: Dictionary, variant_stage: String = "") -> String:
	rules = []
	matches.clear()
	if overlay == null: return ""
	var configured = overlay.get_meta("mgs_removals", [])
	if not configured is Array: return "Map removals must be an array"
	for rule in configured:
		if not rule is Dictionary or not catalog.has(rule.get("asset")) or catalog[rule.asset].kind != "model":
			return "Map removal requires an original model asset ID"
		var part = rule.get("part", -1)
		if not part is int or part < -1 or part > 255: return "Map removal part must be -1 or 0..255"
		if rule.has("anchor"):
			if not rule.anchor is Vector3 or not rule.anchor.is_finite(): return "Map removal anchor must be a finite Vector3"
			var tolerance = rule.get("tolerance", 0.25)
			if (not tolerance is float and not tolerance is int) or not is_finite(tolerance) or tolerance <= 0:
				return "Map removal tolerance must be positive and finite"
		var resolved: Dictionary = rule.duplicate()
		# Whole-model visibility follows the map variant; part indices require identical geometry.
		resolved.asset = ModRegistry.variant_asset(catalog, rule.asset, variant_stage, part != -1)
		rules.append(resolved)
	return ""

func apply(entry: Dictionary, id: int) -> void:
	var parts: Array = matches.get(id, [])
	for rule in rules:
		if rule.asset != entry.asset: continue
		if rule.has("anchor") and anchor(entry.node).distance_to(rule.anchor) > rule.get("tolerance", 0.25): continue
		var part: int = rule.get("part", -1)
		if part not in parts: parts.append(part)
	if parts.is_empty(): return
	if not matches.has(id): print("MGS_VISUAL_REMOVAL instance=%d asset=%s parts=%s" % [id, entry.asset, parts])
	matches[id] = parts
	if -1 in parts:
		entry.node.hide()
		return
	for index in entry.meshes.size():
		var part := str(entry.meshes[index].name).trim_prefix("mesh_").to_int()
		if part in parts:
			entry.meshes[index].hide()
			if not entry.metadata_meshes.is_empty(): entry.metadata_meshes[index].hide()
