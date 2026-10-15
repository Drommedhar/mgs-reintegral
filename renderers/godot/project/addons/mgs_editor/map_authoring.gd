@tool
extends RefCounted

const Removals = preload("res://visual_removals.gd")
const Coordinates = preload("res://map_coordinates.gd")
const Session = preload("res://addons/mgs_editor/map_session.gd")
const MapLights = preload("res://map_lights.gd")
const MapEnvironment = preload("res://map_environment.gd")
const EventLightTemplates = preload("res://event_light_templates.gd")
const MapComposition = preload("res://map_composition.gd")
const MapSource = preload("res://map_source.gd")
var error := ""

func create_map(mods: RefCounted, content: RefCounted, stage: String, disc: int, clip: String = "") -> Node3D:
	var composition := MapComposition.new()
	var root := composition.load_stage(mods, content, stage, disc)
	error = composition.error
	if not error.is_empty(): return null
	if root == null: root = Node3D.new()
	var removals := Removals.new()
	error = removals.configure(root, content.assets, stage)
	if not error.is_empty():
		root.free()
		error = "%s: %s" % [mods.stage_source(stage, disc), error]
		return null
	root.name = stage + "_visuals"
	root.set_meta("mgs_stage", stage)
	root.set_meta("mgs_scene_source", MapSource.describe(content.for_disc(disc), stage, clip))
	root.set_meta("mgs_preview_clip", clip)
	root.set_meta("mgs_removals", removals.rules)
	Coordinates.migrate_to_editor(root)
	return root

func attach_preview(root: Node3D, packed: PackedScene) -> void:
	attach_reference(root, packed.instantiate() as Node3D)

func attach_reference(root: Node3D, preview: Node3D, layout: Dictionary = {}) -> void:
	MapEnvironment.attach(root)
	EventLightTemplates.attach(root)
	var previous_session := root.get_node_or_null("_MapSession")
	if previous_session != null: previous_session.free()
	var previous_lights := root.get_node_or_null("OriginalLights")
	if previous_lights != null: previous_lights.free()
	var old := root.get_node_or_null("LocalMapReference")
	if old != null: old.free()
	preview.name = "LocalMapReference"
	preview.set_meta("mgs_editor_preview", true)
	preview.process_mode = Node.PROCESS_MODE_DISABLED
	preview.transform = Coordinates.reference_transform(root) * preview.transform
	root.add_child(preview)
	for actor in preview.get_children():
		if not actor is Node3D or not actor.has_meta("mgs_asset_id"): continue
		actor.show()
		for mesh in actor.find_children("*", "MeshInstance3D", true, false):
			mesh.show()
			for surface in mesh.mesh.get_surface_count():
				var source := mesh.get_active_material(surface) as ShaderMaterial
				if source == null or source.get_shader_parameter("packet_texture") == null: continue
				var material := StandardMaterial3D.new()
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				material.albedo_texture = source.get_shader_parameter("albedo_texture")
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				mesh.set_surface_override_material(surface, material)
	set_removals(root, root.get_meta("mgs_removals", []))
	var lights := MapLights.create(layout, root.get_meta("mgs_light_overrides", {}))
	lights.set_meta("mgs_editor_preview", true)
	root.add_child(lights)
	if root.get_meta(Coordinates.META, Coordinates.RENDERER) == Coordinates.RENDERER:
		lights.transform = Coordinates.ROTATION
	var session := Session.new()
	session.name = "_MapSession"
	root.add_child(session)
	session.initialize(root, preview, lights)

func removal_for(selected: Node, root: Node3D, part_only: bool) -> Dictionary:
	var reference := root.get_node_or_null("LocalMapReference")
	if reference == null or not reference.is_ancestor_of(selected): return {}
	var actor := selected
	while actor != reference and not actor.has_meta("mgs_asset_id"): actor = actor.get_parent()
	if actor == reference: return {}
	var rule := {"asset": actor.get_meta("mgs_asset_id"), "anchor": Removals.anchor(actor), "tolerance": 0.25}
	if part_only:
		if not selected is MeshInstance3D or not str(selected.name).begins_with("mesh_"): return {}
		rule.part = str(selected.name).trim_prefix("mesh_").to_int()
	return rule

func set_removals(root: Node3D, rules: Array) -> void:
	root.set_meta("mgs_removals", rules)
	var preview := root.get_node_or_null("LocalMapReference")
	if preview == null: return
	for actor in preview.get_children():
		if not actor is Node3D or not actor.has_meta("mgs_asset_id"): continue
		actor.show()
		var meshes := actor.find_children("mesh_*", "MeshInstance3D", true, false)
		for mesh in meshes: mesh.visible = not mesh.get_meta("mgs_reference_hidden", false)
		for rule in rules:
			if rule.asset != actor.get_meta("mgs_asset_id"): continue
			if rule.has("anchor") and Removals.anchor(actor).distance_to(rule.anchor) > rule.get("tolerance", 0.25): continue
			if rule.get("part", -1) == -1: actor.hide()
			else:
				for mesh in meshes:
					if str(mesh.name).trim_prefix("mesh_").to_int() == rule.part: mesh.hide()
