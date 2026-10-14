@tool
extends RefCounted

const ModelContract = preload("res://model_contract.gd")
const ModelEdits = preload("res://model_edits.gd")
var error := ""

func load_model(root: String, catalog: Dictionary, identity: String, mods: RefCounted, mark_original: Callable = Callable(), geometry_only: bool = false) -> Node3D:
	error = ""
	if not catalog.has(identity):
		error = "Prepared model missing: " + identity
		return null
	var original := ModelContract.load_model(root.path_join(catalog[identity].path), geometry_only)
	if original == null:
		error = "Cannot load prepared model: " + identity
		return null
	if mark_original.is_valid(): mark_original.call(original)
	if not mods.replacements.has(identity): return original
	var replacement := ModelContract.load_model(mods.replacements[identity].path)
	if replacement == null: error = "Cannot load replacement: " + identity
	elif replacement.has_meta("mgs_model_reference"):
		var source: String = replacement.get_meta("mgs_model_reference")
		var edits = replacement.get_meta("mgs_part_edits", {})
		replacement.free()
		if source != identity and (not catalog.has(source) or catalog[source].get("sha256", "").is_empty() or catalog[source].sha256 != catalog[identity].get("sha256")):
			error = "Model reference does not match the original asset: " + identity
		elif not edits is Dictionary: error = "Model part edits must be a dictionary"
		else: error = ModelEdits.apply(original, edits)
		if error.is_empty(): return original
		original.free()
		return null
	if error.is_empty(): error = ModelContract.validate(original, replacement)
	original.free()
	if not error.is_empty():
		if replacement != null: replacement.free()
		return null
	return replacement

static func texture_identity(catalog: Dictionary, legacy_id: String, scene_stage: String, scene_disc: int, model_stage: String, model_disc: int) -> String:
	for source in [[scene_disc, scene_stage], [model_disc, model_stage], [model_disc, "init"]]:
		var identity := "mgs/integral-j/disc%d/stage/%s/%s.p" % [source[0], source[1], legacy_id]
		if catalog.has(identity): return identity
	return ""
