@tool
extends RefCounted

const Registry = preload("res://mod_registry.gd")
const Coordinates = preload("res://map_coordinates.gd")
const MapSource = preload("res://map_source.gd")
const Settings = preload("res://map_composition_settings.gd")
var error := ""
var source := ""
var diagnostics := PackedStringArray()

func load_stage(mods: RefCounted, content: RefCounted, stage: String, disc: int) -> Node3D:
	error = ""
	diagnostics.clear()
	source = mods.stage_source(stage, disc)
	var layers: Array[Dictionary] = mods.stage_layers(stage, disc)
	if layers.is_empty(): return null
	if layers.size() == 1: return load_layer(layers[0], content, disc)
	var root := Node3D.new()
	root.name = stage + "_composition"
	Coordinates.mark_editor(root)
	var settings := Settings.new()
	var contributors: Array[Dictionary] = []
	for definition in layers:
		var node := load_layer(definition, content, disc)
		if node == null:
			root.free()
			return null
		Coordinates.migrate_to_editor(node)
		error = settings.append(node, definition, content.assets, stage)
		if not error.is_empty():
			node.free()
			root.free()
			error = "%s (%s): %s" % [definition.mod, definition.source, error]
			return null
		var layer := Node3D.new()
		layer.name = "Layer%d" % contributors.size()
		root.add_child(layer)
		root.move_child(layer, 0)
		layer.owner = root
		layer.add_child(node)
		node.owner = root
		contributors.append({"mod":definition.mod, "source":definition.source})
	settings.apply(root)
	diagnostics = settings.diagnostics()
	root.set_meta("mgs_stage_contributors", contributors)
	root.set_meta("mgs_composition_diagnostics", diagnostics)
	return root

func load_layer(definition: Dictionary, content: RefCounted, disc: int) -> Node3D:
	var target: String = definition.source
	var packed := load(definition.path) as PackedScene
	if packed == null:
		error = "%s (%s): Cannot load stage scene %s" % [definition.mod, target, definition.path]
		return null
	var node := packed.instantiate()
	if not node is Node3D: error = "Stage override root must be Node3D"
	else:
		var saved_source = node.get_meta("mgs_scene_source", {})
		var source_disc := int(saved_source.get("disc", disc)) if saved_source is Dictionary else disc
		error = MapSource.validate(saved_source, content.for_disc(source_disc), Registry.target_stage(target))
		if error.is_empty(): error = Coordinates.validate(node)
	if not error.is_empty():
		node.free()
		error = "%s (%s): %s" % [definition.mod, target, error]
		return null
	for child in node.get_children():
		if child.get_meta("mgs_editor_preview", false): child.free()
	node.set_meta("mgs_mod_package", definition.mod)
	return node
