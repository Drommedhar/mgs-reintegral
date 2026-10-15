@tool
extends Node

const Removals = preload("res://visual_removals.gd")
const MapLights = preload("res://map_lights.gd")
const CameraEdits = preload("res://camera_edits.gd")
const NativeAuthoring = preload("res://addons/mgs_editor/native_authoring.gd")
var camera_player: AnimationPlayer
var camera_original: Animation
var camera_source := {}
var camera_error := ""
var overlay: Node3D
var originals: Array[Node] = []
var actors: Array[Dictionary] = []
var lights: Array[Dictionary] = []
var moved: Array[Dictionary] = []
var native_previews: Array[Dictionary] = []
var native_edits: Array[Node] = []
var attachment_targets: Dictionary = {}
var saving := false
var prepared := false

func initialize(root: Node3D, reference: Node3D, lighting: Node3D) -> void:
	overlay = root
	register_original(reference)
	for actor in reference.get_children():
		if actor.has_meta("mgs_declaration"): continue
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
	if node not in originals: originals.append(node)
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
	if overlay.has_meta("mgs_edit_error"): overlay.remove_meta("mgs_edit_error")
	collect_camera_edits()
	for edit_session in native_edits:
		if not is_instance_valid(edit_session.overlay) or not overlay.is_ancestor_of(edit_session.overlay): continue
		edit_session.error = ""
		edit_session.overlay.set_meta("mgs_part_edits", edit_session.collect_edits())
		if not edit_session.error.is_empty(): overlay.set_meta("mgs_edit_error", edit_session.error)
	native_previews = native_previews.filter(func(entry): return is_instance_valid(entry.binding) and overlay.is_ancestor_of(entry.binding))
	for entry in native_previews:
		if entry.binding.hide_original_object: continue
		var parts: PackedInt32Array = entry.binding.hide_original_parts
		if hidden(entry.node) and not entry.get("initial_hidden", false) and entry.part not in parts: parts.append(entry.part)
		elif not hidden(entry.node) and entry.part in parts: parts.remove_at(parts.find(entry.part))
		entry.binding.hide_original_parts = parts
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

func attach_camera(reference: Node3D, source: Dictionary) -> String:
	camera_error = ""
	camera_player = reference.get_node("OriginalCameraTimeline")
	camera_original = camera_player.get_animation("Original").duplicate()
	camera_source = source
	var edit: Dictionary = overlay.get_meta("mgs_camera_edits", {}).get(source.id, {})
	if edit.is_empty(): return ""
	var restored := CameraEdits.restore(camera_original, edit, source.sha256)
	if restored.has("error"):
		camera_error = restored.error
		return camera_error
	var library := camera_player.get_animation_library("")
	library.remove_animation("Original")
	library.add_animation("Original", restored.animation)
	return ""

func collect_camera_edits() -> void:
	if camera_source.is_empty(): return
	var result := {"error":camera_error}
	if camera_error.is_empty():
		result = CameraEdits.difference(camera_original, camera_player.get_animation("Original") if is_instance_valid(camera_player) and camera_player.has_animation("Original") else null, camera_source.sha256)
	if result.has("error"):
		overlay.set_meta("mgs_edit_error", result.error)
		overlay.set_meta("mgs_camera_error_clip", camera_source.id)
		push_error(result.error)
		return
	if overlay.get_meta("mgs_camera_error_clip", "") == camera_source.id:
		overlay.remove_meta("mgs_edit_error")
		overlay.remove_meta("mgs_camera_error_clip")
	var edits: Dictionary = overlay.get_meta("mgs_camera_edits", {}).duplicate(true)
	if result.edit.is_empty(): edits.erase(camera_source.id)
	else: edits[camera_source.id] = result.edit
	if edits.is_empty():
		if overlay.has_meta("mgs_camera_edits"): overlay.remove_meta("mgs_camera_edits")
	else: overlay.set_meta("mgs_camera_edits", edits)

func prepare_save() -> void:
	if prepared: return
	prepared = true
	var authoring := NativeAuthoring.new()
	authoring.adopt_copied_previews(self)
	collect_edits()
	if not authoring.error.is_empty(): overlay.set_meta("mgs_edit_error", authoring.error)
	# Authored children of references must survive without their retail parents.
	for original in originals:
		if not is_instance_valid(original) or not overlay.is_ancestor_of(original): continue
		for child in original.get_children():
			if child in originals or child.owner != overlay: continue
			var local: Transform3D = child.transform if child is Node3D else Transform3D.IDENTITY
			var transform := relative_transform(child) if child is Node3D else Transform3D.IDENTITY
			moved.append({"node": child, "parent": original, "name": child.name, "index": child.get_index(), "transform": local})
			var destination: Node = overlay
			if original.has_meta("mgs_native_preview_part"):
				destination = original.get_parent()
				transform = original.transform * local
			elif attachment_targets.has(original):
				destination = attachment_targets[original]
				transform = relative_transform(destination).affine_inverse() * transform
			reparent_authored(child, destination)
			if child is Node3D: child.transform = transform
	for original in originals:
		if is_instance_valid(original): original.owner = null
	finish_save.call_deferred()

func finish_save() -> void:
	if not prepared: return
	for original in originals:
		if is_instance_valid(original) and overlay.is_ancestor_of(original): original.owner = overlay
	for entry in moved:
		reparent_authored(entry.node, entry.parent)
		if entry.node is Node3D: entry.node.transform = entry.transform
		entry.node.name = entry.name
		entry.parent.move_child(entry.node, entry.index)
		entry.node.owner = overlay
	moved.clear()
	prepared = false
	saving = false

func detach_for_reload() -> void:
	prepare_save()
	moved.clear()
	prepared = false
	for edit_session in native_edits:
		if is_instance_valid(edit_session.reference): edit_session.reference.free()

func reparent_authored(node: Node, destination: Node) -> void:
	var owned: Array[Node] = []
	for child in [node] + node.find_children("*", "", true, false):
		if child.owner == overlay: owned.append(child)
	for child in owned: child.owner = null
	node.reparent(destination, false)
	for child in owned: child.owner = overlay

func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE: saving = true
