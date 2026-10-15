extends Node3D

const Coordinates = preload("res://map_coordinates.gd")
const Target = preload("res://native_actor_target.gd")
var session_id := PackedByteArray()
var actors: Dictionary = {}
var generations: Dictionary = {}
var current_epoch := 0
var samples := 0
var generic_providers := false

func _init() -> void:
	name = "NativeActors"
	transform = Coordinates.ROTATION

func set_epoch(epoch: int) -> void:
	current_epoch = epoch
	for actor in actors.values():
		actor.body.visible = actor.epoch == epoch and actor.state.visible

func apply(payload: PackedByteArray, context: Dictionary) -> String:
	if payload.size() != 136 or payload.decode_u32(0) != 1: return "Invalid native actor record"
	if session_id.size() != 16 or payload.slice(120, 136) != session_id: return "Native actor belongs to another session"
	if context.is_empty(): return "Native actor arrived without context"
	var action := payload.decode_u32(4)
	var slot := payload.decode_u32(8)
	var generation := payload.decode_u32(12)
	var epoch := payload.decode_u32(16)
	if slot < 1 or slot > 128 or generation == 0 or epoch == 0 or epoch > context.epoch or action not in [1, 2, 3]:
		return "Invalid native actor lifetime fields"
	if action == 1:
		if actors.has(slot) or generation <= generations.get(slot, 0): return "Duplicate or stale native actor spawn"
	elif not actors.has(slot) or actors[slot].generation != generation or actors[slot].epoch != epoch:
		return "Native actor update/retire has no matching incarnation"
	if action == 3:
		actors[slot].body.free()
		actors.erase(slot)
		return ""
	var record := decode(payload)
	var error := validate_record(record)
	if not error.is_empty(): return error
	if action == 2 and record.identity != actors[slot].identity: return "Native actor identity changed within its lifetime"
	if action == 2:
		var existing: Node3D = actors[slot].body
		if not is_instance_valid(existing): return "Native actor anchor was freed externally"
		var parent := existing.get_parent_node_3d()
		if parent != null and is_zero_approx(parent.global_basis.determinant()): return "Native actor anchor has a singular parent"
	var body: Node3D
	if action == 1:
		body = Node3D.new()
		body.name = "actor_%04x_%04x_%d_%d" % [record.identity.provider, record.identity.name, slot, generation]
		body.set_meta("mgs_native_slot", slot)
		body.set_meta("mgs_native_generation", generation)
		body.set_meta("mgs_native_origin", record.identity.duplicate(true))
		add_child(body)
		generations[slot] = generation
		print("MGS_NATIVE_ACTOR spawn=%d generation=%d stage=%s command=%d name=%04x" % [slot, generation, record.identity.stage, record.identity.command_offset, record.identity.name])
	else:
		body = actors[slot].body
	record.body = body
	record.generation = generation
	record.epoch = epoch
	record.slot = slot
	var parent := body.get_parent_node_3d()
	var parent_transform := parent.global_transform if parent != null else Transform3D.IDENTITY
	body.transform = parent_transform.affine_inverse() * global_transform * record.pose
	body.visible = epoch == context.epoch and record.state.visible
	actors[slot] = record
	if record.identity.provider != 0x2abc:
		for field in ["phase", "progress", "duration"]: record.state.erase(field)
	samples += 1
	return ""

func decode(payload: PackedByteArray) -> Dictionary:
	return {
		"identity": {"instance": payload.decode_u32(20), "parts": payload.decode_u32(24),
			"name": payload.decode_u32(28), "map": payload.decode_u32(32), "provider": payload.decode_u32(36),
			"script": payload.decode_u32(48), "command_offset": payload.decode_u32(52),
			"stage": payload.slice(56, 64).get_string_from_ascii(), "script_sha256": payload.slice(64, 96).hex_encode()},
		"tick": payload.decode_u32(40),
		"state": {"phase": payload.decode_u32(44), "progress": payload.decode_s32(108),
			"duration": payload.decode_s32(112), "visible": payload.decode_u32(116) != 0},
		"pose": Transform3D(Basis.IDENTITY, Vector3(payload.decode_float(96), payload.decode_float(100), payload.decode_float(104)))
	}

func validate_record(record: Dictionary) -> String:
	var identity: Dictionary = record.identity
	var state: Dictionary = record.state
	if identity.provider not in [0x2abc, 0xec77] or (identity.provider == 0xec77 and not generic_providers) or identity.instance == 0 or identity.parts < 1 or identity.parts > 256:
		return "Invalid or unnegotiated native actor binding"
	if not record.pose.origin.is_finite(): return "Invalid native actor position"
	if identity.provider == 0x2abc and (state.phase > 3 or state.duration <= 0 or state.progress < 0 or state.progress > state.duration):
		return "Invalid elevator sample"
	if identity.command_offset != 0xffffffff:
		if identity.script >> 16 != 6 or identity.stage.is_empty(): return "Invalid elevator declaration"
		for character in identity.stage:
			if character not in "abcdefghijklmnopqrstuvwxyz0123456789_": return "Invalid elevator declaration stage"
	return ""

func snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for actor in actors.values(): result.append(actor.duplicate(true))
	return result

func resolve_declaration(target: Dictionary) -> Dictionary:
	return Target.resolve(target, actors, current_epoch)
