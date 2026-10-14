@tool
extends RefCounted

const Registry = preload("res://mod_registry.gd")
const Cinematics = preload("res://cinematic_catalog.gd")
const MapSource = preload("res://map_source.gd")
static var descriptions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://addons/mgs_editor/stage_names.json")).stages

static func entries(prepared: Dictionary, asset_root: String) -> Array[Dictionary]:
	var names := {}
	for stage in descriptions:
		if descriptions[stage].get("configured", false): names[stage] = true
	var maps: Dictionary = prepared.get("maps", {})
	for stage in maps: names[stage] = true
	for identity in prepared.get("assets", {}):
		var components := str(identity).split("/")
		if components.size() == 6 and components[3] == "stage": names[components[4]] = true
	var sorted := names.keys()
	sorted.sort()
	var result: Array[Dictionary] = []
	for stage in sorted:
		var layout: Dictionary = maps.get(stage, {})
		var reason := availability(prepared, asset_root, stage)
		var description: Dictionary = descriptions.get(stage, {"name":stage, "kind":"Unclassified"})
		var location: String = description.name.get_slice(" (", 0)
		var label := "%s · %s" % [description.name, stage]
		result.append({"stage":stage, "label":label, "location":location, "name":description.name, "kind":description.kind, "reason":reason,
			"detail":"%s\n%s\n%s" % [layout.get("scope", "No map declaration"), prepared.get("edition", ""), reason],
			"source":source(prepared, stage)})
		for binding in layout.get("clips", []):
			var clip: String = binding.id
			var definition: Dictionary = prepared.get("cinematics", {}).get(clip, {})
			result.append({"stage":stage, "clip":clip,
				"label":"%s · Clip %s · %s" % [description.name, clip.get_file(), stage],
				"location":location, "name":description.name,
				"kind":"Cinematic clip", "reason":availability(prepared, asset_root, stage, clip),
				"detail":"%d source frames. Preview scenery and original camera; edits apply to this stage. Actors, audio and events are not previewed." % definition.get("declared_frames", 0),
				"source":source(prepared, stage, clip)})
	return result

static func modifications(prepared: Dictionary, manifest: Dictionary) -> Dictionary:
	var registry := Registry.new()
	registry.stages = manifest.get("stages", {}).duplicate(true)
	registry.replacements = manifest.get("replacements", {}).duplicate(true)
	registry.materials = manifest.get("materials", {}).duplicate(true)
	registry.effects = manifest.get("effects", {}).duplicate(true)
	registry.inherit_assets(prepared.get("assets", {}))
	var direct: Dictionary = manifest.get("replacements", {}).duplicate()
	direct.merge(manifest.get("materials", {}))
	direct.merge(manifest.get("effects", {}))
	var assets := registry.replacements.duplicate()
	assets.merge(registry.materials)
	assets.merge(registry.effects)
	var result := {}
	for identity in assets:
		var fields := str(identity).split("/")
		if fields.size() != 6: continue
		if prepared.has("disc") and fields[2] != "disc%d" % prepared.disc: continue
		var stage: String = fields[4]
		if not result.has(stage): result[stage] = {"assets":0, "inherited_assets":0}
		result[stage].assets += 1
		if not direct.has(identity): result[stage].inherited_assets += 1
	for stage in descriptions.keys() + prepared.get("maps", {}).keys():
		var original := registry.stage_source(stage, int(prepared.get("disc", 0)))
		if not registry.stages.has(original): continue
		if not result.has(stage): result[stage] = {"assets":0, "inherited_assets":0}
		result[stage].scene = original
	return result

static func edit_label(stage: String, edits: Dictionary) -> String:
	if edits.is_empty(): return "Original"
	var labels: Array[String] = []
	if edits.has("scene"):
		labels.append("Edited scene" if Registry.target_stage(edits.scene) == stage else "From " + str(edits.scene))
	if edits.get("assets", 0) > 0:
		labels.append("%d asset edits" % edits.assets)
		if edits.inherited_assets > 0: labels.append("%d inherited" % edits.inherited_assets)
	return "\n".join(labels)

static func availability(prepared: Dictionary, asset_root: String, stage: String, clip: String = "") -> String:
	if not Registry.valid_stage(stage): return "Invalid stage identifier"
	var layout := Cinematics.layout(prepared, stage, clip)
	if layout.is_empty(): return "No prepared map definition; run campaign content preparation"
	if not layout.get("missing_models", []).is_empty(): return "Missing cinematic scenery: " + str(layout.missing_models)
	if not clip.is_empty() and not prepared.get("cinematics", {}).has(clip): return "Prepare this cinematic source first"
	var models: Array = layout.get("models", []).duplicate()
	for declaration in layout.get("actors", []):
		if declaration.status != "ready": continue
		for role in declaration.models:
			if role.asset not in models: models.append(role.asset)
	if models.is_empty() and layout.get("actors", []).is_empty():
		return "No scenery declared by this clip; actor-only preview is not imported yet" if not clip.is_empty() else "No startup map geometry declared; dynamic or special scene assembly is not imported yet"
	for identity in models:
		var definition: Dictionary = prepared.get("assets", {}).get(identity, {})
		if definition.get("kind") != "model": return "Missing model: " + str(identity)
		if not definition.get("unresolvedTextures", []).is_empty():
			return "Model needs unresolved original textures: " + str(identity)
		if not FileAccess.file_exists(asset_root.path_join(definition.get("path", ""))):
			return "Missing prepared model file: " + str(identity)
	return ""

static func source(prepared: Dictionary, stage: String, clip: String = "") -> Dictionary:
	return MapSource.describe(prepared, stage, clip)

static func source_error(saved: Variant, prepared: Dictionary, stage: String) -> String:
	return MapSource.validate(saved, prepared, stage)

static func launch_profiles(stage: String) -> Array[Dictionary]:
	var profiles: Array[Dictionary] = []
	if stage in ["s00a", "s01a"]:
		profiles.append({"stage":stage, "label":"Current map · fresh native stage",
			"detail":"Starts the map with fresh native state. Does not restore campaign progress."})
	profiles.append({"stage":"title", "label":"Title screen · New Game / Load",
		"detail":"Loads this workspace; use New Game or Load to reach story-dependent and cinematic scenes."})
	return profiles
