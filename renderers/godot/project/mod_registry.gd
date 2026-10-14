@tool
extends RefCounted

const GAMEPLAY_STAGES = {"d00a": "s00a", "d01a": "s01a"}
const ModResources = preload("res://mod_resources.gd")

var replacements: Dictionary = {}
var stages: Dictionary = {}
var stage_contributions: Dictionary = {}
var materials: Dictionary = {}
var effects: Dictionary = {}
var appearances: Dictionary = {}
var postprocess: Dictionary = {}
var ui: Dictionary = {}
var extensions: Array[Dictionary] = []
var loaded: Array[String] = []
var conflicts: Array[Dictionary] = []
var resources := ModResources.new()

func reset() -> void:
	for field in [replacements, stages, stage_contributions, materials, effects, appearances, postprocess, ui]: field.clear()
	extensions.clear()
	loaded.clear()
	conflicts.clear()
	resources = ModResources.new()

func assign(category: String, target: String, definition: Dictionary) -> void:
	var entries: Dictionary = get(category)
	if entries.has(target):
		for conflict in conflicts:
			if conflict.category == category and conflict.target == target: conflict.winner = definition.mod
		conflicts.append({"category":category, "target":target, "winner":definition.mod, "overridden":entries[target].mod})
	entries[target] = definition

func diagnostics() -> PackedStringArray:
	var result := PackedStringArray()
	for conflict in conflicts:
		result.append("%s: %s uses %s instead of %s. Change mod priority or disable an overlapping mod." % [conflict.category, conflict.target, conflict.winner, conflict.overridden])
	return result

static func valid_stage(stage: String) -> bool:
	var pattern := RegEx.new()
	pattern.compile("^[a-z][a-z0-9_]{0,7}$")
	return pattern.search(stage) != null

static func target_stage(target: String) -> String:
	return target.get_slice("/", 1) if "/" in target else target

static func target_disc(target: String) -> int:
	return target.get_slice("/", 0).trim_prefix("disc").to_int() if "/" in target else 0

static func stage_target(stage: String, disc: int) -> String:
	return "disc%d/%s" % [disc, stage]

static func valid_target(target: String) -> bool:
	var fields := target.split("/")
	return valid_stage(target) if fields.size() == 1 else fields.size() == 2 and fields[0] in ["disc1", "disc2"] and valid_stage(fields[1])

func stage_source(stage: String, disc: int = 0) -> String:
	for source in [stage, str(GAMEPLAY_STAGES.get(stage, stage))]:
		for target in [stage_target(source, disc), source]:
			if stages.has(target): return target
	return stage

func stage_definition(stage: String, disc: int = 0) -> Dictionary:
	return stages.get(stage_source(stage, disc), {})

func stage_layers(stage: String, disc: int = 0) -> Array[Dictionary]:
	var targets: Array[String] = []
	for location in [str(GAMEPLAY_STAGES.get(stage, stage)), stage]:
		for target in [location, stage_target(location, disc)]:
			if target not in targets: targets.append(target)
	var selected: Dictionary = {}
	var layers: Array[Dictionary] = []
	for target in targets:
		var entries: Array = stage_contributions.get(target, [stages[target]] if stages.has(target) else [])
		for entry in entries:
			var layer: Dictionary = entry.duplicate()
			layer.source = target
			selected[layer.mod] = layer
			layers.append(layer)
	# A mod's explicit variant is an independent snapshot of its inherited scene.
	return layers.filter(func(layer): return selected[layer.mod] == layer)

static func variant_asset(catalog: Dictionary, identity: String, stage: String, identical_content: bool = true) -> String:
	var fields := identity.split("/")
	if fields.size() != 6 or fields[4] != GAMEPLAY_STAGES.get(stage, ""): return identity
	fields[4] = stage
	var candidate := "/".join(fields)
	if not catalog.has(candidate) or not catalog.has(identity): return identity
	if not identical_content: return candidate
	var digest: String = catalog[identity].get("sha256", "")
	return candidate if not digest.is_empty() and digest == catalog[candidate].get("sha256") else identity

func inherit_assets(catalog: Dictionary) -> void:
	for entries in [replacements, materials, effects]:
		for identity in entries.keys():
			for stage in GAMEPLAY_STAGES:
				var candidate := variant_asset(catalog, identity, stage)
				if not entries.has(candidate): entries[candidate] = entries[identity]

static func asset_path(root: String, relative: String) -> String:
	return ModResources.asset_path(root, relative)

func configure(catalog: Dictionary, paths: Array, priorities: Dictionary = {}) -> String:
	reset()
	var manifests: Array[Dictionary] = []
	var ids: Dictionary = {}
	for path in paths:
		if not path is String:
			return "Mod manifest paths must be strings"
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary or parsed.get("schema") != 1:
			return "Invalid mod manifest: " + path
		if not parsed.get("id") is String or parsed.id.is_empty() or ids.has(parsed.id):
			return "Mod IDs must be nonempty and unique: " + path
		var absolute := ProjectSettings.globalize_path(path).simplify_path()
		if priorities.has(absolute): parsed.priority = priorities[absolute]
		if not parsed.get("priority", 0) is float and not parsed.get("priority", 0) is int:
			return "Mod priority must be numeric: " + path
		if not is_finite(parsed.get("priority", 0)): return "Mod priority must be finite: " + path
		for field in ["replacements", "stages", "materials", "effects", "appearances", "postprocess", "ui", "resources"]:
			if not parsed.get(field, {}) is Dictionary: return "Mod %s must be an object: %s" % [field, path]
		if not parsed.get("extensions", []) is Array: return "Mod extensions must be an array: " + path
		ids[parsed.id] = true
		parsed["root"] = str(path).get_base_dir()
		manifests.append(parsed)
	manifests.sort_custom(func(a, b):
		if a.get("priority", 0) == b.get("priority", 0): return a.id < b.id
		return a.get("priority", 0) < b.get("priority", 0))
	for manifest in manifests:
		var error := register_manifest(catalog, manifest)
		if not error.is_empty():
			return "%s: %s" % [manifest.id, error]
		loaded.append(manifest.id)
	inherit_assets(catalog)
	return ""

func register_manifest(catalog: Dictionary, manifest: Dictionary) -> String:
	var resource_error := resources.register_package(manifest.id, manifest.root, manifest.get("resources", {}))
	if not resource_error.is_empty(): return resource_error
	for identity in manifest.get("replacements", {}):
		var entry = manifest.replacements[identity]
		if not catalog.has(identity) or not entry is Dictionary or not entry.get("path") is String:
			return "Unknown asset or invalid replacement: " + str(identity)
		var path := asset_path(manifest.root, entry.path)
		if path.is_empty() or not FileAccess.file_exists(path):
			return "Missing replacement or path outside mod folder: " + entry.path
		var extension := path.get_extension().to_lower()
		if catalog[identity].kind == "model" and extension not in ["gltf", "glb", "tscn"]:
			return "Model replacement requires glTF, GLB or TSCN"
		if catalog[identity].kind == "texture" and extension not in ["png", "webp"]:
			return "Texture replacement requires PNG or WebP"
		if entry.get("lighting", "unlit") not in ["unlit", "lit"]:
			return "Replacement lighting must be unlit or lit"
		assign("replacements", identity, {"path": path, "lighting": entry.get("lighting", "unlit"), "mod": manifest.id})
	for stage in manifest.get("stages", {}):
		var entry = manifest.stages[stage]
		if not valid_target(stage) or not entry is Dictionary or not entry.get("scene") is String:
			return "Invalid stage override: " + str(stage)
		var path := asset_path(manifest.root, entry.scene)
		if path.is_empty() or path.get_extension() != "tscn" or not FileAccess.file_exists(path):
			return "Stage %s requires an existing TSCN inside the mod folder: %s" % [stage, entry.scene]
		if not entry.get("original_lighting", false) is bool:
			return "original_lighting must be boolean"
		var definition := {"path": path, "original_lighting": entry.get("original_lighting", false), "mod": manifest.id}
		if not stage_contributions.has(stage): stage_contributions[stage] = []
		stage_contributions[stage].append(definition)
		stages[stage] = definition
	var material_error := register_materials(catalog, manifest)
	if not material_error.is_empty(): return material_error
	var effect_error := register_effects(catalog, manifest)
	if not effect_error.is_empty(): return effect_error
	var appearance_error := register_appearances(manifest)
	if not appearance_error.is_empty(): return appearance_error
	var postprocess_error := register_postprocess(manifest)
	if not postprocess_error.is_empty(): return postprocess_error
	var ui_error := register_ui(manifest)
	if not ui_error.is_empty(): return ui_error
	return register_extensions(manifest)

func register_ui(manifest: Dictionary) -> String:
	for slot in manifest.get("ui", {}):
		var entry = manifest.ui[slot]
		if slot not in ["goggles", "bars", "subtitles", "radar", "inventory", "codec", "options", "save_load", "title", "display_settings"] or not entry is Dictionary or not entry.get("scene") is String or entry.size() != 1:
			return "Unknown UI slot or invalid scene entry"
		var path := asset_path(manifest.root, entry.scene)
		if path.is_empty() or path.get_extension() != "tscn" or not FileAccess.file_exists(path):
			return "UI scene must be a TSCN inside the mod folder"
		assign("ui", slot, {"scene": path, "mod": manifest.id})
	return ""

func register_postprocess(manifest: Dictionary) -> String:
	for kind in manifest.get("postprocess", {}):
		var entry = manifest.postprocess[kind]
		if kind not in ["night_vision", "thermal_vision"] or not entry is Dictionary or not entry.get("effect") is String or entry.size() != 1:
			return "Postprocess requires a night_vision or thermal_vision effect resource"
		var path := asset_path(manifest.root, entry.effect)
		if path.is_empty() or path.get_extension() != "tres" or not FileAccess.file_exists(path):
			return "Postprocess effect must be a TRES inside the mod folder"
		assign("postprocess", kind, {"effect": path, "mod": manifest.id})
	return ""

func register_appearances(manifest: Dictionary) -> String:
	for kind in manifest.get("appearances", {}):
		var entry = manifest.appearances[kind]
		if kind != "camouflage" or not entry is Dictionary or not entry.get("material") is String:
			return "Object appearance requires a camouflage material"
		if entry.size() != 1: return "Unknown object appearance fields"
		var path := asset_path(manifest.root, entry.material)
		if path.is_empty() or path.get_extension() != "tres" or not FileAccess.file_exists(path):
			return "Appearance material must be a TRES inside the mod folder"
		assign("appearances", kind, {"material": path, "mod": manifest.id})
	return ""

func register_effects(catalog: Dictionary, manifest: Dictionary) -> String:
	for identity in manifest.get("effects", {}):
		if identity != "mgs/effects/snow" and catalog.get(identity, {}).get("kind") != "texture":
			return "Unknown world-effect texture identity: " + str(identity)
		var entry = manifest.effects[identity]
		if not entry is Dictionary: return "Effect override must be an object: " + str(identity)
		for field in entry:
			if field not in ["material", "depth_shader"]: return "Unknown effect override field: " + str(field)
		var definition := {"mod": manifest.id}
		for field in ["material", "depth_shader"]:
			if not entry.get(field) is String: return "Effect requires " + field
			var path := asset_path(manifest.root, entry[field])
			var extension := "tres" if field == "material" else "gdshader"
			if path.is_empty() or path.get_extension() != extension or not FileAccess.file_exists(path):
				return "Effect %s must be an existing %s inside the mod folder" % [field, extension]
			definition[field] = path
		assign("effects", identity, definition)
	return ""

func register_materials(catalog: Dictionary, manifest: Dictionary) -> String:
	const MAPS = ["albedo", "normal", "orm", "emission"]
	const FACTORS = {"roughness": 1.0, "metallic": 1.0, "normal_scale": 4.0, "emission_energy": 16.0}
	for identity in manifest.get("materials", {}):
		var entry = manifest.materials[identity]
		if not catalog.has(identity) or catalog[identity].kind != "texture" or not entry is Dictionary:
			return "PBR material requires an existing texture identity: " + str(identity)
		var definition: Dictionary = {"mod": manifest.id}
		for key in entry:
			if key in MAPS:
				if not entry[key] is String: return "PBR texture paths must be strings"
				var path := asset_path(manifest.root, entry[key])
				if path.is_empty() or path.get_extension().to_lower() not in ["png", "webp"] or not FileAccess.file_exists(path):
					return "PBR map must be a PNG/WebP inside the mod folder: " + str(key)
				definition[key] = path
			elif key in FACTORS:
				if not entry[key] is float and not entry[key] is int: return "PBR factors must be numeric"
				if not is_finite(entry[key]) or entry[key] < 0 or entry[key] > FACTORS[key]: return "PBR factor out of range: " + str(key)
				definition[key] = float(entry[key])
			else: return "Unknown PBR material field: " + str(key)
		assign("materials", identity, definition)
	return ""

func register_extensions(manifest: Dictionary) -> String:
	for entry in manifest.get("extensions", []):
		if not entry is Dictionary or not entry.get("path") is String or not entry.get("class") is String:
			return "Extension requires path and class strings"
		if entry.get("api_version") != 1: return "Unsupported visual mod API version"
		var path := asset_path(manifest.root, entry.path)
		if path.is_empty() or path.get_extension() != "gdextension" or not FileAccess.file_exists(path):
			return "Extension must be a GDExtension descriptor inside the mod folder"
		if entry.class.is_empty(): return "Extension class must not be empty"
		extensions.append({"path": path, "class": entry.class, "mod": manifest.id})
	return ""
