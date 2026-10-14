@tool
extends RefCounted

const Registry = preload("res://mod_registry.gd")

static func layout(prepared: Dictionary, stage: String, clip: String = "") -> Dictionary:
	var base: Dictionary = prepared.get("maps", {}).get(stage, {})
	if clip.is_empty(): return base
	for binding in base.get("clips", []):
		if binding.id != clip: continue
		var result := base.duplicate()
		result.models = binding.models
		result.missing_models = binding.missing_models
		result.scope = "Cinematic scenery · " + clip
		return result
	return {}

static func source(prepared: Dictionary, clip: String) -> Dictionary:
	var definition: Dictionary = prepared.get("cinematics", {}).get(clip, {})
	return {"id":clip, "sha256":definition.get("sha256", "")} if not definition.is_empty() else {}

static func validate_files(directory: String, prepared: Dictionary) -> String:
	var clips = prepared.get("cinematics", {})
	if not clips is Dictionary: return "Invalid cinematic catalog"
	for identity in clips:
		if not str(identity).begins_with("mgs/integral-j/disc%d/demo/" % prepared.disc): return "Cinematic belongs to a different disc: " + str(identity)
		var definition = clips[identity]
		if not definition is Dictionary or not definition.get("path") is String: return "Invalid cinematic source: " + str(identity)
		var path := Registry.asset_path(directory, definition.path)
		if path.is_empty() or not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != definition.get("prepared_sha256", ""):
			return "Prepared cinematic is missing or changed: " + str(identity)
	return ""

static func camera_data(directory: String, prepared: Dictionary, clip: String) -> Dictionary:
	var definition: Dictionary = prepared.get("cinematics", {}).get(clip, {})
	var path := Registry.asset_path(directory, definition.get("path", ""))
	if path.is_empty() or not FileAccess.file_exists(path): return {}
	if FileAccess.get_sha256(path) != definition.get("prepared_sha256", ""): return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("schema") != 1 or data.get("id") != clip or not data.get("camera") is Array: return {}
	var previous := -1
	for row in data.camera:
		if not row is Array or row.size() != 9: return {}
		for value in row:
			if (not value is int and not value is float) or not is_finite(value) or int(value) != value: return {}
		if row[0] < previous or row[0] > definition.get("declared_frames", 0): return {}
		previous = int(row[0])
	return data
