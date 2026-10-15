@tool
extends RefCounted

const DiscMap = preload("res://addons/mgs_editor/disc_map.gd")
const Composition = preload("res://map_composition.gd")
const Coordinates = preload("res://map_coordinates.gd")
const Authoring = preload("res://addons/mgs_editor/map_authoring.gd")
const Cinematics = preload("res://cinematic_catalog.gd")
const Camera = preload("res://cinematic_source.gd")
const NativeAuthoring = preload("res://addons/mgs_editor/native_authoring.gd")
const MapLights = preload("res://map_lights.gd")
const Removals = preload("res://visual_removals.gd")
var error := ""
var diagnostics := PackedStringArray()

func create(content: RefCounted, profile: RefCounted, stage: String, disc: int, clip: String = "") -> Node3D:
	var prepared: Dictionary = content.for_disc(disc)
	var loader := DiscMap.new()
	var reference := loader.load_map(content.root, prepared, stage, "", clip, profile.paths(), profile.priorities())
	error = loader.error
	if reference == null: return null
	var composition := Composition.new()
	var map := composition.load_stage(loader.mods, content, stage, disc)
	error = composition.error
	if not error.is_empty():
		reference.free()
		return null
	if map == null: map = Node3D.new()
	Coordinates.migrate_to_editor(map)
	diagnostics = loader.mods.diagnostics()
	diagnostics.append_array(composition.diagnostics)
	var layout := Cinematics.layout(prepared, stage, clip)
	var removals := Removals.new()
	error = removals.configure(map, content.assets, stage)
	if error.is_empty(): error = MapLights.validate(layout, map.get_meta("mgs_light_overrides", {}))
	if not error.is_empty():
		map.free()
		reference.free()
		return null
	map.set_meta("mgs_removals", removals.rules)
	Authoring.new().attach_reference(map, reference, layout)
	var session := map.get_node("_MapSession")
	if not clip.is_empty():
		error = Camera.attach(reference, content.root, prepared, clip)
		if error.is_empty(): error = session.attach_camera(reference, Cinematics.source(prepared, clip))
	if error.is_empty():
		var actors := NativeAuthoring.new()
		actors.attach_declarations(map, reference, session)
		if not actors.error.is_empty():
			error = actors.error
			map.free()
			return null
		actors.attach_previews(map, content.assets, content.root, session)
		error = actors.error
	if not error.is_empty():
		map.free()
		return null
	return map
