extends RefCounted

var session_id := PackedByteArray()
var models: Dictionary = {}
var verified_models: Dictionary = {}
var disc_identity := false

func apply(payload: PackedByteArray) -> String:
	if payload.size() != (76 if disc_identity else 72): return "Invalid model source declaration length"
	if session_id.size() != 16 or payload.slice(24, 40) != session_id:
		return "Model source belongs to another session"
	var model := payload.decode_u32(0)
	var source := payload.decode_u32(4)
	var size := payload.decode_u32(8)
	var offset := payload.decode_u32(12)
	var stage := payload.slice(16, 24).get_string_from_ascii()
	var disc := payload.decode_u32(72) if disc_identity else 1
	if disc not in [1, 2]: return "Invalid model source disc"
	var extension := (source >> 16) + 97
	if model > 65535 or extension not in [107, 122] or size == 0 or size > 64 * 1024 * 1024 or offset >= size:
		return "Invalid model source fields"
	for character in stage:
		if character not in "abcdefghijklmnopqrstuvwxyz0123456789_": return "Invalid model source stage"
	if stage.is_empty(): return "Missing model source stage"
	if extension == 107 and (offset != 0 or (source & 65535) != model): return "Invalid standalone model identity"
	var identity := "mgs/integral-j/disc%d/stage/%s/%04x.k" % [disc, stage, model]
	if not models.has(identity) and models.size() >= 65536: return "Model source declaration limit exceeded"
	models[identity] = {"source": source, "size": size, "offset": offset, "sha256": payload.slice(40, 72).hex_encode()}
	verified_models.erase(identity)
	return ""

func validate(identity: String, asset: Dictionary) -> String:
	if not models.has(identity): return "Missing native model source: " + identity
	var record: Dictionary = models[identity]
	if (record.source >> 16) + 97 != 107:
		return "Packed model needs prepared archive/subresource provenance: " + identity
	if asset.get("sha256", "") != record.sha256:
		return "Native model source differs from prepared content: " + identity
	verified_models[identity] = record.sha256
	return ""
