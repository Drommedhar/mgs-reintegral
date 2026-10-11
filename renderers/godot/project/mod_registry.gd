@tool
extends RefCounted

const GAMEPLAY_STAGES = {"d00a": "s00a", "d01a": "s01a"}

var replacements: Dictionary = {}
var stages: Dictionary = {}
var materials: Dictionary = {}
var extensions: Array[Dictionary] = []
var loaded: Array[String] = []

func stage_source(stage: String) -> String:
	return stage if stages.has(stage) else str(GAMEPLAY_STAGES.get(stage, stage))

func stage_definition(stage: String) -> Dictionary:
	return stages.get(stage_source(stage), {})

static func variant_asset(catalog: Dictionary, identity: String, stage: String) -> String:
	var fields := identity.split("/")
	if fields.size() != 6 or fields[4] != GAMEPLAY_STAGES.get(stage, ""): return identity
	fields[4] = stage
	var candidate := "/".join(fields)
	if not catalog.has(candidate) or not catalog.has(identity): return identity
	var digest: String = catalog[identity].get("sha256", "")
	return candidate if not digest.is_empty() and digest == catalog[candidate].get("sha256") else identity

func inherit_assets(catalog: Dictionary) -> void:
	for entries in [replacements, materials]:
		for identity in entries.keys():
			for stage in GAMEPLAY_STAGES:
				var candidate := variant_asset(catalog, identity, stage)
				if not entries.has(candidate): entries[candidate] = entries[identity]

static func asset_path(root: String, relative: String) -> String:
	if relative.is_empty() or relative.is_absolute_path():
		return ""
	var resolved := root.path_join(relative).simplify_path()
	return resolved if resolved.begins_with(root.simplify_path().trim_suffix("/") + "/") else ""

func configure(catalog: Dictionary, paths: Array) -> String:
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
		if not parsed.get("priority", 0) is float and not parsed.get("priority", 0) is int:
			return "Mod priority must be numeric: " + path
		for field in ["replacements", "stages", "materials"]:
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
		replacements[identity] = {"path": path, "lighting": entry.get("lighting", "unlit"), "mod": manifest.id}
	for stage in manifest.get("stages", {}):
		var entry = manifest.stages[stage]
		if stage not in ["s00a", "s01a", "d00a", "d01a"] or not entry is Dictionary or not entry.get("scene") is String:
			return "Invalid prototype stage override: " + str(stage)
		var path := asset_path(manifest.root, entry.scene)
		if path.is_empty() or path.get_extension() != "tscn" or not FileAccess.file_exists(path):
			return "Stage override requires an existing TSCN inside the mod folder"
		if not entry.get("original_lighting", true) is bool:
			return "original_lighting must be boolean"
		stages[stage] = {"path": path, "original_lighting": entry.get("original_lighting", true), "mod": manifest.id}
	var material_error := register_materials(catalog, manifest)
	if not material_error.is_empty(): return material_error
	return register_extensions(manifest)

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
		materials[identity] = definition
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
