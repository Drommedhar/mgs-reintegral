extends SceneTree

const Context = preload("res://native_context.gd")
var failures: Array[String] = []
const SESSION = "abcdef0123456789abcdef0123456789"

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func packet(epoch: int, sequence: int, stage: String, tick: int, pause: int) -> PackedByteArray:
	var payload := PackedByteArray()
	payload.resize(36)
	payload.encode_u32(0, 2)
	payload.encode_u32(4, epoch)
	payload.encode_u64(8, sequence)
	payload.encode_u32(16, tick)
	payload.encode_u32(20, pause)
	payload.encode_s32(24, 2)
	var name := stage.to_ascii_buffer()
	for index in range(name.size()):
		payload[28 + index] = name[index]
	payload.append_array(SESSION.hex_decode())
	return payload

func _initialize() -> void:
	var context := Context.new()
	context.session_id = SESSION.hex_decode()
	check(context.apply(packet(0, 1, "", 0, 0)).is_empty(), "Pre-stage context rejected")
	check(context.apply(packet(1, 2, "s00a", 10, 0)).is_empty(), "Stage entry rejected")
	check(context.apply(packet(1, 3, "s00a", 11, 4)).is_empty(), "Paused native tick rejected")
	check(context.current.pause_mask == 4 and context.current.actor_loop_tick == 11, "Native clock/pause changed")
	check(context.apply(packet(2, 4, "s00a", 12, 0)).is_empty(), "Same-name reload lost generation")
	var saved := context.current.duplicate(true)
	var wrong_session := packet(2, 5, "s00a", 13, 0)
	wrong_session[36] ^= 1
	check(not context.apply(wrong_session).is_empty() and context.current == saved, "Wrong-session context mutated state")
	check(context.current.session_id == SESSION, "Public session identity not exposed")
	for invalid in [packet(2, 4, "s00a", 12, 0), packet(2, 6, "s00a", 13, 0),
		packet(1, 5, "s00a", 13, 0), packet(2, 5, "d00a", 13, 0),
		packet(3, 5, "", 13, 0), packet(3, 5, "../x", 13, 0), PackedByteArray()]:
		check(not context.apply(invalid).is_empty(), "Malformed/stale context accepted")
		check(context.current == saved, "Rejected context partially changed state")
	check(context.apply(packet(3, 5, "d00a", 13, 0)).is_empty(), "Cinematic stage transition rejected")
	var scoped := Context.new()
	scoped.session_id = SESSION.hex_decode()
	scoped.disc_identity = true
	var sample := packet(1, 1, "s16a", 13, 0)
	sample.encode_u32(0, 3)
	sample.resize(56)
	sample.encode_u32(52, 1)
	check(scoped.apply(sample).is_empty(), "Disc-1 context rejected")
	sample.encode_u64(8, 2)
	sample.encode_u32(52, 2)
	check(not scoped.apply(sample).is_empty() and scoped.current.disc == 1, "Disc changed without a new epoch")
	sample.encode_u32(4, 2)
	check(scoped.apply(sample).is_empty() and scoped.current.disc == 2, "Disc transition rejected")
	var cinematic := Context.new()
	cinematic.session_id = SESSION.hex_decode()
	cinematic.disc_identity = true
	cinematic.cinematic_context = true
	var clip := packet(1, 1, "d00a", 20, 0)
	clip.resize(80)
	clip.encode_u32(0, 4)
	clip.encode_u32(52, 1)
	clip.encode_u32(56, 1)
	clip.encode_u32(60, 1)
	clip.encode_u32(64, 0)
	clip.encode_u32(68, 120)
	clip.encode_s32(72, 43)
	clip.encode_u32(76, 1)
	check(cinematic.apply(clip).is_empty() and cinematic.current.cinematic.frame == 43, "Applied cinematic frame not published")
	clip.encode_u64(8, 2)
	clip.encode_s32(72, 121)
	check(not cinematic.apply(clip).is_empty() and cinematic.current.cinematic.frame == 43, "Out-of-range camera sample mutated context")
	clip.encode_s32(72, 43)
	clip.encode_u32(76, 0)
	check(cinematic.apply(clip).is_empty() and not cinematic.current.cinematic.active, "Cinematic end did not restore default ownership")
	var vision := Context.new()
	vision.session_id = SESSION.hex_decode()
	vision.disc_identity = true
	vision.cinematic_context = true
	vision.vision_context = true
	clip.resize(84)
	clip.encode_u32(0, 5)
	for mode in [0, 1, 2, 0]:
		clip.encode_u64(8, vision.current.get("sequence", 0) + 1)
		clip.encode_u32(80, mode)
		check(vision.apply(clip).is_empty() and vision.current.vision_mode == mode, "Native vision state transition lost")
	clip.encode_u64(8, 5)
	clip.encode_u32(80, 3)
	check(not vision.apply(clip).is_empty() and vision.current.vision_mode == 0, "Invalid vision mode mutated context")
	var loading := Context.new()
	loading.session_id = SESSION.hex_decode()
	loading.disc_identity = true
	loading.cinematic_context = true
	loading.vision_context = true
	loading.loading_context = true
	clip.resize(96)
	clip.encode_u32(0, 6)
	clip.encode_u32(80, 0)
	clip.encode_u64(8, 1)
	clip.encode_u32(84, 1)
	for index in 7: clip[88 + index] = "opening".unicode_at(index)
	check(loading.apply(clip).is_empty() and loading.current.loading_stage == "opening", "Upcoming stage hint rejected")
	clip.encode_u64(8, 2)
	clip.encode_u32(84, 0)
	check(not loading.apply(clip).is_empty(), "Loading end with stale stage accepted")
	for index in 8: clip[88 + index] = 0
	check(loading.apply(clip).is_empty() and not loading.current.loading, "Loading end rejected")
	var api := preload("res://visual_mod_api.gd").new()
	api.publish_native_context(context.current)
	var external: Dictionary = api.get_native_context()
	external.epoch = 99
	check(api.get_native_context().epoch == 3, "Mod mutated native context through returned dictionary")
	api.free()
	for failure in failures:
		push_error(failure)
	print("NATIVE CONTEXT TEST failures=%d" % failures.size())
	quit(0 if failures.is_empty() else 1)
