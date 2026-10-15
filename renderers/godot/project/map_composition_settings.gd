@tool
extends RefCounted

const Removals = preload("res://visual_removals.gd")
const Templates = preload("res://event_light_templates.gd")
var lights: Dictionary = {}
var cameras: Dictionary = {}
var removals: Array = []
var providers: Dictionary = {}
var event_templates: Node3D

func record(target: String, definition: Dictionary) -> void:
	if not providers.has(target): providers[target] = []
	providers[target].append("%s (%s)" % [definition.mod, definition.source])

func append(node: Node3D, definition: Dictionary, catalog: Dictionary, stage: String) -> String:
	var light_edits = node.get_meta("mgs_light_overrides", {})
	if not light_edits is Dictionary: return "Original light overrides must be a dictionary"
	for identity in light_edits:
		if not light_edits[identity] is Dictionary: return "Light properties must be a dictionary: " + str(identity)
		if not lights.has(identity): lights[identity] = {}
		for property in light_edits[identity]:
			record("original light %s/%s" % [identity, property], definition)
			lights[identity][property] = light_edits[identity][property]
	var camera_edits = node.get_meta("mgs_camera_edits", {})
	if not camera_edits is Dictionary: return "Camera edits must be a dictionary"
	for clip in camera_edits:
		record("camera clip " + str(clip), definition)
		cameras[clip] = camera_edits[clip]
	var removal_set := Removals.new()
	var removal_error := removal_set.configure(node, catalog, stage)
	if not removal_error.is_empty(): return removal_error
	for rule in removal_set.rules:
		if rule not in removals: removals.append(rule)
	for environment in node.find_children("*", "WorldEnvironment", true, false):
		for property in ["environment", "camera_attributes", "compositor"]:
			if environment.get(property) != null: record("world " + property, definition)
	var templates := Templates.find_in(node)
	if templates != null:
		var template_error := Templates.validate(templates)
		if not template_error.is_empty(): return template_error
		record("event light templates", definition)
		event_templates = templates
		event_templates.hide()
	record("original_lighting", definition)
	return ""

func apply(root: Node3D) -> void:
	root.set_meta("mgs_light_overrides", lights)
	root.set_meta("mgs_camera_edits", cameras)
	root.set_meta("mgs_removals", removals)
	if event_templates != null: root.set_meta(Templates.PATH_META, root.get_path_to(event_templates))

func diagnostics() -> PackedStringArray:
	var result := PackedStringArray()
	for target in providers:
		var entries: Array = providers[target]
		if entries.size() < 2: continue
		result.append("%s uses %s instead of %s. Independent scene additions remain enabled; change priority within a scope or edit the exact scenario." % [target, entries.back(), ", ".join(entries.slice(0, -1))])
	return result
