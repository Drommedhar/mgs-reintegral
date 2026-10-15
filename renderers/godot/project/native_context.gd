extends RefCounted

var current: Dictionary = {}
var session_id := PackedByteArray()
var session_bound := true
var disc_identity := false
var cinematic_context := false
var vision_context := false
var loading_context := false

func apply(payload: PackedByteArray) -> String:
	var expected_size := 96 if loading_context else 84 if vision_context else 80 if cinematic_context else 56 if disc_identity else 52 if session_bound else 36
	var expected_schema := 6 if loading_context else 5 if vision_context else 4 if cinematic_context else 3 if disc_identity else 2 if session_bound else 1
	if payload.size() != expected_size or payload.decode_u32(0) != expected_schema:
		return "Invalid native context size or schema"
	if session_id.size() != 16 or session_bound and payload.slice(36, 52) != session_id:
		return "Native context belongs to a different session"
	var disc := payload.decode_u32(52) if disc_identity else 1
	if disc not in [1, 2]: return "Invalid native disc identity"
	var epoch := payload.decode_u32(4)
	var sequence := payload.decode_u64(8)
	var stage_bytes := payload.slice(28, 36)
	var terminated := false
	for character in stage_bytes:
		if character == 0:
			terminated = true
		elif terminated or not (character >= 97 and character <= 122 or character >= 48 and character <= 57 or character == 95):
			return "Invalid native context stage name"
	var stage := stage_bytes.get_string_from_ascii()
	if (epoch == 0) != stage.is_empty() or sequence <= 0:
		return "Invalid native context generation or sequence"
	if current.is_empty() and sequence != 1:
		return "Native context must begin at sequence 1"
	if not current.is_empty():
		if sequence != current.sequence + 1 or epoch < current.epoch:
			return "Native context sequence gap or stale generation"
		if epoch == current.epoch and (stage != current.stage or disc != current.disc):
			return "Native stage or disc changed without a new generation"
	var cinematic := {}
	if cinematic_context:
		cinematic = {"generation":payload.decode_u32(56), "disc":payload.decode_u32(60), "sector":payload.decode_u32(64),
			"total":payload.decode_u32(68), "frame":payload.decode_s32(72), "active":payload.decode_u32(76)}
		if cinematic.active > 1 or cinematic.disc not in [0, 1, 2] or cinematic.frame < -1:
			return "Invalid native cinematic context"
		if cinematic.active and (cinematic.disc == 0 or cinematic.generation == 0 or cinematic.frame > cinematic.total):
			return "Invalid active cinematic source or frame"
		if not current.is_empty() and cinematic.generation < current.get("cinematic", {}).get("generation", 0):
			return "Stale cinematic generation"
		var previous: Dictionary = current.get("cinematic", {})
		if cinematic.active and previous.get("active", false) and cinematic.generation == previous.generation:
			if cinematic.disc != previous.disc or cinematic.sector != previous.sector or cinematic.total != previous.total or cinematic.frame < previous.frame:
				return "Cinematic source changed or rewound without a new generation"
	var vision := payload.decode_u32(80) if vision_context else 0
	if vision > 2: return "Invalid native vision mode"
	var loading := payload.decode_u32(84) if loading_context else 0
	var loading_stage := payload.slice(88, 96).get_string_from_ascii() if loading_context else ""
	if loading > 1 or bool(loading) != (not loading_stage.is_empty()): return "Invalid native loading state"
	for character in loading_stage:
		if character not in "abcdefghijklmnopqrstuvwxyz0123456789_": return "Invalid loading stage name"
	current = {"session_id": session_id.hex_encode(), "epoch": epoch, "sequence": sequence, "stage": stage, "disc": disc, "vision_mode": vision,
		"loading":bool(loading), "loading_stage":loading_stage,
		"actor_loop_tick": payload.decode_u32(16), "pause_mask": payload.decode_u32(20),
		"passage_ticks": payload.decode_s32(24), "cinematic":cinematic}
	return ""
