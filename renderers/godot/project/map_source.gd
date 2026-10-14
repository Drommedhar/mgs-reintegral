@tool
extends RefCounted

const Cinematics = preload("res://cinematic_catalog.gd")

static func describe(prepared: Dictionary, stage: String, clip: String = "") -> Dictionary:
	var result := {"stage":stage, "edition":prepared.get("edition", ""), "disc":prepared.get("disc", 0),
		"stage_dir_sha256":prepared.get("stageDirSha256", ""),
		"source_image_sha256":prepared.get("sourceImageSha256", ""),
		"script_sha256":prepared.get("maps", {}).get(stage, {}).get("script_sha256", "")}
	if not clip.is_empty():
		result.clip = clip
		result.clip_sha256 = Cinematics.source(prepared, clip).get("sha256", "")
	return result

static func validate(saved: Variant, prepared: Dictionary, stage: String) -> String:
	if not saved is Dictionary: return "Map source must be a dictionary"
	var current := describe(prepared, stage, str(saved.get("clip", "")))
	for key in saved:
		if not saved[key] in ["", 0] and saved[key] != current.get(key):
			return "Map source differs from this workspace (%s). Load its matching prepared content." % key
	return ""
