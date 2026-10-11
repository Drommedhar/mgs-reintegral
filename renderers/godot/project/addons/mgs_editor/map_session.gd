@tool
extends Node

const Removals = preload("res://visual_removals.gd")
const MapLights = preload("res://map_lights.gd")
var overlay: Node3D
var originals: Array[Node] = []
var actors: Array[Dictionary] = []
var lights: Array[Dictionary] = []
var moved: Array[Dictionary] = []
var saving := false
var prepared := false

func initialize(root: Node3D, reference: Node3D, lighting: Node3D) -> void:
	overlay = root
	register_original(reference)
	for actor in reference.get_children():
		if not actor.has_meta("mgs_asset_id"): continue
		var rule := {"asset": actor.get_meta("mgs_asset_id"), "anchor": Removals.anchor(actor), "tolerance": 0.25}
		var parts: Array[Dictionary] = []
		for mesh in actor.find_children("mesh_*", "MeshInstance3D", true, false):
			if mesh.get_meta("mgs_reference_hidden", false): continue
			var part := rule.duplicate()
			part.part = str(mesh.name).trim_prefix("mesh_").to_int()
			parts.append({"node": mesh, "rule": part})
		actors.append({"node": actor, "rule": rule, "parts": parts})
	if lighting != null:
		register_original(lighting, false)
		for light in lighting.get_children():
			lights.append({"node": light, "id": light.get_meta("mgs_light_id"), "defaults": light.get_meta("mgs_light_defaults")})

func register_original(node: Node, retail_geometry: bool = true) -> void:
	originals.append(node)
	if retail_geometry: node.set_meta("mgs_retail_derived", true)
	node.owner = overlay
	for child in node.get_children(): register_original(child, retail_geometry)

func hidden(node: Variant) -> bool:
	if not is_instance_valid(node) or not overlay.is_ancestor_of(node): return true
	while node != overlay:
		if node is Node3D and not node.visible: return true
		node = node.get_parent()
	return false

func relative_transform(node: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != overlay:
		if current is Node3D: result = current.transform * result
		current = current.get_parent()
	return result

func represented(rule: Dictionary) -> bool:
	for actor in actors:
		if rule.get("asset") != actor.rule.asset: continue
		if not rule.has("anchor") or actor.rule.anchor.distance_to(rule.anchor) > rule.get("tolerance", 0.25): continue
		if rule.get("part", -1) == -1: return true
		for part in actor.parts:
			if rule.part == part.rule.part: return true
	return false

func collect_edits() -> void:
	var rules: Array = overlay.get_meta("mgs_removals", []).filter(func(rule): return not represented(rule))
	for actor in actors:
		if hidden(actor.node): rules.append(actor.rule)
		else:
			for part in actor.parts:
				if hidden(part.node): rules.append(part.rule)
	overlay.set_meta("mgs_removals", rules)
	var overrides: Dictionary = overlay.get_meta("mgs_light_overrides", {}).duplicate(true)
	for entry in lights:
		var changes := {}
		if not is_instance_valid(entry.node) or not overlay.is_ancestor_of(entry.node):
			changes.visible = false
		else:
			for property in entry.defaults:
				var value = entry.node.get(property)
				if property == "position": value = relative_transform(entry.node).origin
				if property == "visible": value = not hidden(entry.node)
				if value != entry.defaults[property]: changes[property] = value
		if changes.is_empty(): overrides.erase(entry.id)
		else: overrides[entry.id] = changes
	overlay.set_meta("mgs_light_overrides", overrides)

func prepare_save() -> void:
	if prepared: return
	prepared = true
	collect_edits()
	# Authored children of references must survive without their retail parents.
	for original in originals:
		if not is_instance_valid(original) or not overlay.is_ancestor_of(original): continue
		for child in original.get_children():
			if child in originals or child.owner != overlay: continue
			var local: Transform3D = child.transform if child is Node3D else Transform3D.IDENTITY
			var transform := relative_transform(child) if child is Node3D else Transform3D.IDENTITY
			moved.append({"node": child, "parent": original, "name": child.name, "index": child.get_index(), "transform": local})
			child.reparent(overlay, false)
			if child is Node3D: child.transform = transform
	for original in originals:
		if is_instance_valid(original): original.owner = null
	finish_save.call_deferred()

func finish_save() -> void:
	if not prepared: return
	for original in originals:
		if is_instance_valid(original) and overlay.is_ancestor_of(original): original.owner = overlay
	for entry in moved:
		entry.node.reparent(entry.parent, false)
		if entry.node is Node3D: entry.node.transform = entry.transform
		entry.node.name = entry.name
		entry.parent.move_child(entry.node, entry.index)
		entry.node.owner = overlay
	moved.clear()
	prepared = false
	saving = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE: saving = true
