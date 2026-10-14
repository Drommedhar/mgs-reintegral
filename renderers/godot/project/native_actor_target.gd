extends RefCounted

const FIELDS = ["stage", "script", "script_sha256", "command_offset", "provider"]

static func validate(target: Dictionary) -> String:
	if target.size() != FIELDS.size(): return "Actor target requires stage, script, script_sha256, command_offset and provider"
	for field in FIELDS:
		if not target.has(field): return "Missing actor target field: " + field
	if not target.stage is String or target.stage.is_empty() or target.stage.length() > 8:
		return "Actor target requires a source stage"
	for character in target.stage:
		if character not in "abcdefghijklmnopqrstuvwxyz0123456789_": return "Invalid actor target stage"
	if not target.script_sha256 is String or target.script_sha256.length() != 64:
		return "Actor target requires the complete source script SHA-256"
	for character in target.script_sha256:
		if character not in "0123456789abcdef": return "Actor target SHA-256 must be lowercase hexadecimal"
	for field in ["script", "command_offset", "provider"]:
		var value = target[field]
		if not value is int and not (value is float and is_finite(value) and value == floor(value)):
			return "Actor target %s must be an integer" % field
	if target.script < 6 * 65536 or target.script > 7 * 65536 - 1:
		return "Actor target must reference a GCX script resource"
	if target.command_offset < 0 or target.command_offset >= 0xffffffff:
		return "Actor target requires a resolved declaration offset"
	if int(target.provider) not in [0x2abc, 0xec77]: return "Unsupported actor target provider"
	return ""

static func resolve(target: Dictionary, actors: Dictionary, epoch: int) -> Dictionary:
	var error := validate(target)
	if not error.is_empty(): return {"status": "invalid", "message": error}
	var matches: Array[Dictionary] = []
	for actor in actors.values():
		if actor.epoch != epoch: continue
		var matches_declaration := true
		for field in FIELDS:
			if actor.identity[field] != target[field]:
				matches_declaration = false
				break
		if matches_declaration: matches.append(actor)
	if matches.is_empty(): return {"status": "inactive", "message": "Declaration has no active actor in this scene"}
	if matches.size() > 1: return {"status": "ambiguous", "message": "Declaration has multiple active actors", "count": matches.size()}
	if not is_instance_valid(matches[0].body): return {"status": "unavailable", "message": "Native actor anchor was freed externally"}
	return {"status": "available", "actor": matches[0].duplicate(true)}
