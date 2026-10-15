extends SceneTree

const Gate = preload("res://session_gate.gd")
var failures: Array[String] = []
const TOKEN = "0123456789abcdef0123456789abcdef"

func new_gate() -> Gate:
	var gate := Gate.new()
	check(gate.configure_token(TOKEN).is_empty(), "Test token configuration failed")
	return gate

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func hello() -> PackedByteArray:
	var payload := PackedByteArray()
	payload.resize(40)
	payload.encode_u32(0, Gate.MAGIC)
	payload.encode_u32(4, Gate.VERSION)
	payload.encode_u32(8, Gate.MINOR)
	payload.encode_u32(12, Gate.VERTEX_STRIDE)
	payload.encode_u32(16, 7)
	payload.encode_u32(20, 5)
	for index in range(16):
		payload[24 + index] = TOKEN.hex_decode()[index]
	return payload

func _initialize() -> void:
	var valid := hello()
	for invalid in ["", "f".repeat(31), "f".repeat(33), "g".repeat(32), "-" + "f".repeat(31)]:
		check(not Gate.new().configure_token(invalid).is_empty(), "Invalid token setting accepted")
	var wrong_token := valid.duplicate()
	wrong_token[24] ^= 1
	check(not new_gate().accept(1, wrong_token).is_empty(), "Wrong session accepted")
	check(not Gate.new().accept(1, valid).is_empty(), "Unconfigured session accepted")
	for operation in range(2, 13):
		var unopened := new_gate()
		check(not unopened.accept(operation, PackedByteArray()).is_empty(), "Pre-HELLO command accepted: %d" % operation)
		check(not unopened.accept(1, valid).is_empty(), "Rejected session recovered without reconnect")
		check(not unopened.ready, "Rejected session marked ready")
	for length in [0, 4, 8, 12, 24, 39, 41, 48]:
		var malformed := valid.duplicate()
		malformed.resize(length)
		check(not new_gate().accept(1, malformed).is_empty(), "Invalid HELLO size accepted: %d" % length)
	for offset in [0, 4, 12]:
		var incompatible := valid.duplicate()
		incompatible.encode_u32(offset, 0)
		check(not new_gate().accept(1, incompatible).is_empty(), "Invalid HELLO field accepted: %d" % offset)
	var session := new_gate()
	check(session.accept(1, valid).is_empty() and session.ready, "Valid HELLO rejected")
	check(session.reply().decode_u32(8) == 5, "Unavailable scene capability advertised")
	var scene_required := valid.duplicate()
	scene_required.encode_u32(20, 7)
	check(not new_gate().accept(1, scene_required).is_empty(), "Required scene capability silently dropped")
	var scene_session := new_gate()
	scene_session.capabilities |= Gate.SCENE_MESHES
	check(scene_session.accept(1, scene_required).is_empty(), "Enabled scene capability rejected")
	check(scene_session.reply().decode_u32(8) == 7, "Scene negotiation lost capabilities")
	var future := valid.duplicate()
	future.encode_u32(8, Gate.MINOR + 1)
	future.encode_u32(16, 63)
	var optional_session := new_gate()
	check(optional_session.accept(1, future).is_empty(), "Unknown optional capability rejected")
	check(optional_session.reply().decode_u32(4) == Gate.MINOR and optional_session.selected == 29, "Minor/capability intersection incorrect")
	check(optional_session.accept(12, PackedByteArray()).is_empty(), "Negotiated context rejected")
	future.encode_u32(20, 37)
	check(not new_gate().accept(1, future).is_empty(), "Unknown required capability accepted")
	future.encode_u32(16, 5)
	check(not new_gate().accept(1, future).is_empty(), "Requirement absent from offered set accepted")
	for operation in [2, 3, 4, 5, 6, 7, 8, 11]:
		check(session.accept(operation, PackedByteArray()).is_empty(), "Negotiated command rejected: %d" % operation)
	check(scene_session.accept(9, PackedByteArray()).is_empty(), "Negotiated scene rejected")
	check(scene_session.accept(10, PackedByteArray()).is_empty(), "Negotiated world rejected")
	check(not optional_session.accept(9, PackedByteArray()).is_empty(), "Unnegotiated scene command accepted")
	check(not session.accept(1, valid).is_empty(), "Duplicate HELLO accepted")
	check(not session.accept(7, PackedByteArray()).is_empty(), "Failed session accepted FRAME")
	var modern := valid.duplicate()
	modern.encode_u32(16, 31)
	modern.encode_u32(20, 29)
	var identified := new_gate()
	check(identified.accept(1, modern).is_empty(), "Session identity negotiation failed")
	check(identified.reply().size() == 28 and identified.reply().slice(12) == identified.public_id, "Public identity missing from reply")
	check(identified.public_id != TOKEN.hex_decode(), "Private token exposed as public identity")
	var independent := new_gate()
	check(independent.accept(1, modern).is_empty(), "Second session negotiation failed")
	check(independent.public_id != identified.public_id, "Separate sessions reused public identity")
	modern.encode_u32(8, 1)
	check(not new_gate().accept(1, modern).is_empty(), "Session identity accepted below supported minor")
	modern.encode_u32(20, 13)
	var older := new_gate()
	check(older.accept(1, modern).is_empty() and older.reply().size() == 12 and older.selected == 13, "Minor 1 compatibility failed")
	var sourced := valid.duplicate()
	sourced.encode_u32(16, 127)
	sourced.encode_u32(20, 66)
	var source_gate := new_gate()
	source_gate.capabilities |= Gate.SCENE_MESHES | Gate.MODEL_SOURCES
	check(source_gate.accept(1, sourced).is_empty() and source_gate.accept(15, PackedByteArray()).is_empty(), "Model source negotiation failed")
	sourced.encode_u32(8, 3)
	var old_source_gate := new_gate()
	old_source_gate.capabilities = source_gate.capabilities
	check(not old_source_gate.accept(1, sourced).is_empty(), "Model sources accepted below minor 4")
	check(not scene_session.accept(15, PackedByteArray()).is_empty(), "Unnegotiated model source accepted")
	var disc_hello := hello()
	disc_hello.encode_u32(16, 511)
	disc_hello.encode_u32(20, 511)
	var disc_gate := new_gate()
	disc_gate.capabilities = 511
	check(disc_gate.accept(1, disc_hello).is_empty() and disc_gate.selected & Gate.DISC_IDENTITY, "Disc identity capability was not negotiated")
	disc_hello.encode_u32(8, 5)
	var old_disc_gate := new_gate()
	old_disc_gate.capabilities = 511
	check(not old_disc_gate.accept(1, disc_hello).is_empty(), "Disc-aware layouts accepted below minor 6")
	var camera_hello := hello()
	camera_hello.encode_u32(16, 1023)
	camera_hello.encode_u32(20, 1023)
	var camera_gate := new_gate()
	camera_gate.capabilities = 1023
	check(camera_gate.accept(1, camera_hello).is_empty() and camera_gate.selected & Gate.CINEMATIC_CONTEXT, "Cinematic clock capability was not negotiated")
	camera_hello.encode_u32(8, 6)
	var old_camera_gate := new_gate()
	old_camera_gate.capabilities = 1023
	check(not old_camera_gate.accept(1, camera_hello).is_empty(), "Cinematic context accepted below minor 7")
	var view_hello := hello()
	view_hello.encode_u32(16, 2047)
	view_hello.encode_u32(20, 2047)
	var view_gate := new_gate()
	view_gate.capabilities = 2047
	check(view_gate.accept(1, view_hello).is_empty() and view_gate.selected & Gate.INDEPENDENT_VIEW, "Independent view semantics were not negotiated")
	view_hello.encode_u32(8, 7)
	var old_view_gate := new_gate()
	old_view_gate.capabilities = 2047
	check(not old_view_gate.accept(1, view_hello).is_empty(), "Independent view semantics accepted below minor 8")
	var snow_hello := hello()
	snow_hello.encode_u32(16, 4095)
	snow_hello.encode_u32(20, 4095)
	var snow_gate := new_gate()
	snow_gate.capabilities = 4095
	check(snow_gate.accept(1, snow_hello).is_empty() and snow_gate.selected & Gate.WORLD_SNOW, "World snow semantics were not negotiated")
	snow_hello.encode_u32(8, 8)
	var old_snow_gate := new_gate()
	old_snow_gate.capabilities = 4095
	check(not old_snow_gate.accept(1, snow_hello).is_empty(), "World snow semantics accepted below minor 9")
	var surface_hello := hello()
	surface_hello.encode_u32(16, 8191)
	surface_hello.encode_u32(20, 8191)
	var surface_gate := new_gate()
	surface_gate.capabilities = 8191
	check(surface_gate.accept(1, surface_hello).is_empty() and surface_gate.selected & Gate.WORLD_SURFACES, "World surface semantics were not negotiated")
	surface_hello.encode_u32(8, 9)
	var old_surface_gate := new_gate()
	old_surface_gate.capabilities = 8191
	check(not old_surface_gate.accept(1, surface_hello).is_empty(), "World surface semantics accepted below minor 10")
	var appearance_hello := hello()
	appearance_hello.encode_u32(16, 16383)
	appearance_hello.encode_u32(20, 16383)
	var appearance_gate := new_gate()
	appearance_gate.capabilities = 16383
	check(appearance_gate.accept(1, appearance_hello).is_empty() and appearance_gate.selected & Gate.OBJECT_APPEARANCE, "Object appearance was not negotiated")
	appearance_hello.encode_u32(8, 10)
	var old_appearance_gate := new_gate()
	old_appearance_gate.capabilities = 16383
	check(not old_appearance_gate.accept(1, appearance_hello).is_empty(), "Object appearance accepted below minor 11")
	var vision_hello := hello()
	vision_hello.encode_u32(16, 32767)
	vision_hello.encode_u32(20, 32767)
	var vision_gate := new_gate()
	vision_gate.capabilities = 32767
	check(vision_gate.accept(1, vision_hello).is_empty() and vision_gate.selected & Gate.VISION_CONTEXT, "Vision context was not negotiated")
	for dependency in [Gate.SCENE_MESHES, Gate.NATIVE_CONTEXT, Gate.SESSION_CONTEXT, Gate.DISC_IDENTITY, Gate.CINEMATIC_CONTEXT]:
		var incomplete := vision_hello.duplicate()
		incomplete.encode_u32(16, 32767 & ~dependency)
		incomplete.encode_u32(20, 32767 & ~dependency)
		var incomplete_gate := new_gate()
		incomplete_gate.capabilities = 32767
		check(not incomplete_gate.accept(1, incomplete).is_empty() and not incomplete_gate.ready, "Vision context accepted without dependency %d" % dependency)
	vision_hello.encode_u32(8, 11)
	var old_vision_gate := new_gate()
	old_vision_gate.capabilities = 32767
	check(not old_vision_gate.accept(1, vision_hello).is_empty(), "Vision context accepted below minor 12")
	var thermal_hello := hello()
	thermal_hello.encode_u32(16, 65535)
	thermal_hello.encode_u32(20, 65535)
	var thermal_gate := new_gate()
	thermal_gate.capabilities = 65535
	check(thermal_gate.accept(1, thermal_hello).is_empty(), "Thermal vision negotiation failed")
	for missing in [Gate.VISION_CONTEXT, Gate.SCENE_MESHES]:
		var incomplete := thermal_hello.duplicate()
		incomplete.encode_u32(16, 65535 & ~missing)
		incomplete.encode_u32(20, 65535 & ~missing)
		var incomplete_gate := new_gate()
		incomplete_gate.capabilities = 65535
		check(not incomplete_gate.accept(1, incomplete).is_empty(), "Thermal vision accepted without its dependencies")
	thermal_hello.encode_u32(8, 12)
	var old_thermal_gate := new_gate()
	old_thermal_gate.capabilities = 65535
	check(not old_thermal_gate.accept(1, thermal_hello).is_empty(), "Thermal vision accepted below minor 13")
	var ui_hello := hello()
	ui_hello.encode_u32(16, 131071)
	ui_hello.encode_u32(20, 131071)
	var ui_gate := new_gate()
	ui_gate.capabilities = 131071
	check(ui_gate.accept(1, ui_hello).is_empty() and ui_gate.accept(17, PackedByteArray()).is_empty(), "Goggles UI negotiation failed")
	for missing in [Gate.GOGGLES_UI, Gate.SCENE_MESHES, Gate.SESSION_CONTEXT, Gate.NATIVE_CONTEXT, Gate.DISC_IDENTITY, Gate.CINEMATIC_CONTEXT]:
		var incomplete := ui_hello.duplicate()
		incomplete.encode_u32(16, 131071 & ~missing)
		incomplete.encode_u32(20, 131071 & ~missing)
		var incomplete_gate := new_gate()
		incomplete_gate.capabilities = 131071
		var rejected := not incomplete_gate.accept(1, incomplete).is_empty()
		check(rejected or not incomplete_gate.accept(17, PackedByteArray()).is_empty(), "Goggles UI accepted without dependency %d" % missing)
	ui_hello.encode_u32(8, 14)
	var old_ui_gate := new_gate()
	old_ui_gate.capabilities = 131071
	check(not old_ui_gate.accept(1, ui_hello).is_empty(), "Goggles UI accepted below minor 15")
	var bars_hello := hello()
	bars_hello.encode_u32(16, 262143)
	bars_hello.encode_u32(20, 262143)
	var bars_gate := new_gate()
	bars_gate.capabilities = 262143
	check(bars_gate.accept(1, bars_hello).is_empty() and bars_gate.accept(18, PackedByteArray()).is_empty(), "Status bars negotiation failed")
	for missing in [Gate.STATUS_BARS, Gate.SCENE_MESHES, Gate.SESSION_CONTEXT, Gate.NATIVE_CONTEXT, Gate.DISC_IDENTITY, Gate.CINEMATIC_CONTEXT]:
		var incomplete := bars_hello.duplicate()
		incomplete.encode_u32(16, 262143 & ~missing)
		incomplete.encode_u32(20, 262143 & ~missing)
		var incomplete_gate := new_gate()
		incomplete_gate.capabilities = 262143
		var rejected := not incomplete_gate.accept(1, incomplete).is_empty()
		check(rejected or not incomplete_gate.accept(18, PackedByteArray()).is_empty(), "Status bars accepted without dependency %d" % missing)
	bars_hello.encode_u32(8, 15)
	var old_bars_gate := new_gate()
	old_bars_gate.capabilities = 262143
	check(not old_bars_gate.accept(1, bars_hello).is_empty(), "Status bars accepted below minor 16")
	var subtitle_hello := hello()
	subtitle_hello.encode_u32(16, 524287)
	subtitle_hello.encode_u32(20, 524287)
	var subtitle_gate := new_gate()
	subtitle_gate.capabilities = 524287
	check(subtitle_gate.accept(1, subtitle_hello).is_empty() and subtitle_gate.accept(19, PackedByteArray()).is_empty(), "Subtitles negotiation failed")
	for missing in [Gate.SUBTITLES, Gate.SCENE_MESHES, Gate.SESSION_CONTEXT, Gate.NATIVE_CONTEXT, Gate.DISC_IDENTITY, Gate.CINEMATIC_CONTEXT]:
		var incomplete := subtitle_hello.duplicate()
		incomplete.encode_u32(16, 524287 & ~missing)
		incomplete.encode_u32(20, 524287 & ~missing)
		var incomplete_gate := new_gate()
		incomplete_gate.capabilities = 524287
		var rejected := not incomplete_gate.accept(1, incomplete).is_empty()
		check(rejected or not incomplete_gate.accept(19, PackedByteArray()).is_empty(), "Subtitles accepted without dependency %d" % missing)
	subtitle_hello.encode_u32(8, 16)
	var old_subtitle_gate := new_gate()
	old_subtitle_gate.capabilities = 524287
	check(not old_subtitle_gate.accept(1, subtitle_hello).is_empty(), "Subtitles accepted below minor 17")
	var radar_hello := hello()
	radar_hello.encode_u32(16, 1048575)
	radar_hello.encode_u32(20, 1048575)
	var radar_gate := new_gate()
	radar_gate.capabilities = 1048575
	check(radar_gate.accept(1, radar_hello).is_empty() and radar_gate.accept(20, PackedByteArray()).is_empty(), "Radar negotiation failed")
	for missing in [Gate.RADAR, Gate.SCENE_MESHES, Gate.SESSION_CONTEXT, Gate.NATIVE_CONTEXT, Gate.DISC_IDENTITY, Gate.CINEMATIC_CONTEXT]:
		var incomplete := radar_hello.duplicate()
		incomplete.encode_u32(16, 1048575 & ~missing)
		incomplete.encode_u32(20, 1048575 & ~missing)
		var incomplete_gate := new_gate()
		incomplete_gate.capabilities = 1048575
		var rejected := not incomplete_gate.accept(1, incomplete).is_empty()
		check(rejected or not incomplete_gate.accept(20, PackedByteArray()).is_empty(), "Radar accepted without dependency %d" % missing)
	radar_hello.encode_u32(8, 17)
	var old_radar_gate := new_gate()
	old_radar_gate.capabilities = 1048575
	check(not old_radar_gate.accept(1, radar_hello).is_empty(), "Radar accepted below minor 18")
	var inventory_hello := hello()
	inventory_hello.encode_u32(16, 2097151)
	inventory_hello.encode_u32(20, 2097151)
	var inventory_gate := new_gate()
	inventory_gate.capabilities = 2097151
	check(inventory_gate.accept(1, inventory_hello).is_empty() and inventory_gate.accept(21, PackedByteArray()).is_empty(), "Inventory negotiation failed")
	for missing in [Gate.INVENTORY, Gate.SCENE_MESHES, Gate.SESSION_CONTEXT, Gate.NATIVE_CONTEXT, Gate.DISC_IDENTITY, Gate.CINEMATIC_CONTEXT]:
		var incomplete := inventory_hello.duplicate()
		incomplete.encode_u32(16, 2097151 & ~missing)
		incomplete.encode_u32(20, 2097151 & ~missing)
		var incomplete_gate := new_gate()
		incomplete_gate.capabilities = 2097151
		var rejected := not incomplete_gate.accept(1, incomplete).is_empty()
		check(rejected or not incomplete_gate.accept(21, PackedByteArray()).is_empty(), "Inventory accepted without dependency %d" % missing)
	inventory_hello.encode_u32(8, 18)
	var old_inventory_gate := new_gate()
	old_inventory_gate.capabilities = 2097151
	check(not old_inventory_gate.accept(1, inventory_hello).is_empty(), "Inventory accepted below minor 19")
	var display_hello := hello()
	display_hello.encode_u32(16, 67108863)
	display_hello.encode_u32(20, 67108863)
	var display_gate := new_gate()
	display_gate.capabilities = 67108863
	check(display_gate.accept(1, display_hello).is_empty() and display_gate.accept(26, PackedByteArray()).is_empty(), "Display negotiation failed")
	for missing in [Gate.DISPLAY, Gate.SCENE_MESHES, Gate.SESSION_CONTEXT]:
		var incomplete := display_hello.duplicate()
		incomplete.encode_u32(16, 67108863 & ~missing)
		incomplete.encode_u32(20, 67108863 & ~missing)
		var incomplete_gate := new_gate()
		incomplete_gate.capabilities = 67108863
		check(not incomplete_gate.accept(1, incomplete).is_empty() or not incomplete_gate.accept(26, PackedByteArray()).is_empty(), "Display accepted without dependency")
	display_hello.encode_u32(8, 23)
	var old_display_gate := new_gate()
	old_display_gate.capabilities = 67108863
	check(not old_display_gate.accept(1, display_hello).is_empty(), "Display accepted below minor 24")
	var capture_hello := hello()
	capture_hello.encode_u32(16, 134217727)
	capture_hello.encode_u32(20, 134217727)
	var capture_gate := new_gate()
	capture_gate.capabilities = 134217727
	check(capture_gate.accept(1, capture_hello).is_empty() and capture_gate.selected & Gate.INPUT_CAPTURE, "Input capture negotiation failed")
	capture_hello.encode_u32(8, 24)
	var old_capture_gate := new_gate()
	old_capture_gate.capabilities = 134217727
	check(not old_capture_gate.accept(1, capture_hello).is_empty(), "Old minor accepted input capture")
	var saves_hello := hello()
	saves_hello.encode_u32(16,268435455)
	saves_hello.encode_u32(20,268435455)
	var saves_gate := new_gate()
	saves_gate.capabilities=268435455
	check(saves_gate.accept(1,saves_hello).is_empty() and saves_gate.accept(27,PackedByteArray()).is_empty(),"Save actions negotiation failed")
	for missing in [Gate.SAVE_UI,Gate.INPUT_CAPTURE,Gate.SAVE_ACTIONS,Gate.NATIVE_CONTEXT]:
		var incomplete := saves_hello.duplicate()
		incomplete.encode_u32(16,268435455 & ~missing)
		incomplete.encode_u32(20,268435455 & ~missing)
		var candidate := new_gate()
		candidate.capabilities=268435455
		check(not candidate.accept(1,incomplete).is_empty() or not candidate.accept(27,PackedByteArray()).is_empty(),"Save action accepted without dependency")
	saves_hello.encode_u32(8,25)
	var old_saves := new_gate()
	old_saves.capabilities=268435455
	check(not old_saves.accept(1,saves_hello).is_empty(),"Old minor accepted save actions")
	var action_hello := hello()
	action_hello.encode_u32(16,536870911)
	action_hello.encode_u32(20,536870911)
	var action_gate := new_gate()
	action_gate.capabilities=536870911
	check(action_gate.accept(1,action_hello).is_empty() and action_gate.accept(28,PackedByteArray()).is_empty(),"Options actions negotiation failed")
	for missing in [Gate.OPTIONS,Gate.INPUT_CAPTURE,Gate.OPTIONS_ACTIONS,Gate.NATIVE_CONTEXT]:
		var incomplete := action_hello.duplicate()
		incomplete.encode_u32(16,536870911 & ~missing)
		incomplete.encode_u32(20,536870911 & ~missing)
		var candidate := new_gate()
		candidate.capabilities=536870911
		check(not candidate.accept(1,incomplete).is_empty() or not candidate.accept(28,PackedByteArray()).is_empty(),"Options action accepted without dependency")
	action_hello.encode_u32(8,26)
	var old_actions := new_gate()
	old_actions.capabilities=536870911
	check(not old_actions.accept(1,action_hello).is_empty(),"Old minor accepted Options actions")
	var title_hello := hello()
	title_hello.encode_u32(16,1073741823)
	title_hello.encode_u32(20,1073741823)
	var title_gate := new_gate()
	title_gate.capabilities=1073741823
	check(title_gate.accept(1,title_hello).is_empty() and title_gate.accept(29,PackedByteArray()).is_empty(),"Title actions negotiation failed")
	for missing in [Gate.TITLE_ACTIONS,Gate.TITLE,Gate.INPUT_CAPTURE,Gate.SCENE_MESHES,Gate.NATIVE_CONTEXT,Gate.SESSION_CONTEXT,Gate.DISC_IDENTITY,Gate.CINEMATIC_CONTEXT]:
		var incomplete := title_hello.duplicate()
		incomplete.encode_u32(16,1073741823 & ~missing)
		incomplete.encode_u32(20,1073741823 & ~missing)
		var candidate := new_gate()
		candidate.capabilities=1073741823
		check(not candidate.accept(1,incomplete).is_empty() or not candidate.accept(29,PackedByteArray()).is_empty(),"Title action accepted without dependency %d"%missing)
	title_hello.encode_u32(8,27)
	var old_title := new_gate()
	old_title.capabilities=1073741823
	check(not old_title.accept(1,title_hello).is_empty(),"Old minor accepted title actions")
	title_hello.encode_u32(20,536870911)
	var optional_title := new_gate()
	optional_title.capabilities=1073741823
	check(optional_title.accept(1,title_hello).is_empty() and optional_title.selected==536870911,"Optional title actions did not downgrade")
	var codec_hello := hello()
	codec_hello.encode_u32(16,2147483647)
	codec_hello.encode_u32(20,2147483647)
	var codec_gate := new_gate()
	codec_gate.capabilities=2147483647
	check(codec_gate.accept(1,codec_hello).is_empty() and codec_gate.accept(30,PackedByteArray()).is_empty(),"Codec actions negotiation failed")
	for missing in [Gate.CODEC_ACTIONS,Gate.CODEC,Gate.INPUT_CAPTURE,Gate.NATIVE_CONTEXT,Gate.SESSION_CONTEXT,Gate.SCENE_MESHES,Gate.DISC_IDENTITY,Gate.CINEMATIC_CONTEXT]:
		var incomplete := codec_hello.duplicate()
		incomplete.encode_u32(16,2147483647 & ~missing)
		incomplete.encode_u32(20,2147483647 & ~missing)
		var candidate := new_gate()
		candidate.capabilities=2147483647
		check(not candidate.accept(1,incomplete).is_empty() or not candidate.accept(30,PackedByteArray()).is_empty(),"Codec action accepted without dependency")
	codec_hello.encode_u32(8,28)
	var old_codec := new_gate()
	old_codec.capabilities=2147483647
	check(not old_codec.accept(1,codec_hello).is_empty(),"Old minor accepted Codec actions")
	codec_hello.encode_u32(20,1073741823)
	var optional_codec := new_gate()
	optional_codec.capabilities=2147483647
	check(optional_codec.accept(1,codec_hello).is_empty() and optional_codec.selected==1073741823,"Optional Codec actions did not downgrade")
	inventory_actions_checks()
	for failure in failures:
		push_error(failure)
	print("SESSION GATE TEST failures=%d" % failures.size())
	quit(0 if failures.is_empty() else 1)

func inventory_actions_checks() -> void:
	var inventory_hello := hello()
	inventory_hello.encode_u32(16,0xffffffff)
	inventory_hello.encode_u32(20,0xffffffff)
	var inventory_gate := new_gate()
	inventory_gate.capabilities=0xffffffff
	check(inventory_gate.accept(1,inventory_hello).is_empty() and inventory_gate.selected==0xffffffff and inventory_gate.accept(31,PackedByteArray()).is_empty(),"High-bit inventory capability negotiation failed")
	for missing in [Gate.INVENTORY_ACTIONS,Gate.INVENTORY,Gate.INPUT_CAPTURE,Gate.SCENE_MESHES,Gate.SESSION_CONTEXT,Gate.NATIVE_CONTEXT,Gate.DISC_IDENTITY,Gate.CINEMATIC_CONTEXT]:
		var incomplete := inventory_hello.duplicate()
		incomplete.encode_u32(16,0xffffffff & ~missing)
		incomplete.encode_u32(20,0xffffffff & ~missing)
		var candidate := new_gate()
		candidate.capabilities=0xffffffff
		check(not candidate.accept(1,incomplete).is_empty() or not candidate.accept(31,PackedByteArray()).is_empty(),"Inventory action accepted without dependency")
	inventory_hello.encode_u32(8,29)
	var old_inventory := new_gate()
	old_inventory.capabilities=0xffffffff
	check(not old_inventory.accept(1,inventory_hello).is_empty(),"Old minor accepted inventory actions")
	inventory_hello.encode_u32(20,0x7fffffff)
	var optional_inventory := new_gate()
	optional_inventory.capabilities=0xffffffff
	check(optional_inventory.accept(1,inventory_hello).is_empty() and optional_inventory.selected==0x7fffffff,"Optional inventory actions did not downgrade")
