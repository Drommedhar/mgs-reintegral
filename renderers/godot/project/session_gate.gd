extends RefCounted

const MAGIC = 0x3152474d
const VERSION = 15
const MINOR = 35
const VERTEX_STRIDE = 20
const COMMAND_RENDERING = 1
const SCENE_MESHES = 2
const DEBUG_TEXT = 4
const NATIVE_CONTEXT = 8
const SESSION_CONTEXT = 16
const RETAINED_PALETTES = 32
const MODEL_SOURCES = 64
const ELEVATOR_ACTORS = 128
const DISC_IDENTITY = 256
const CINEMATIC_CONTEXT = 512
const INDEPENDENT_VIEW = 1024
const WORLD_SNOW = 2048
const WORLD_SURFACES = 4096
const OBJECT_APPEARANCE = 8192
const VISION_CONTEXT = 16384
const THERMAL_VISION = 32768
const GOGGLES_UI = 65536
const STATUS_BARS = 131072
const SUBTITLES = 262144
const RADAR = 524288
const INVENTORY = 1048576
const CODEC = 2097152
const OPTIONS = 4194304
const SAVE_UI = 8388608
const TITLE = 16777216
const DISPLAY = 33554432
const INPUT_CAPTURE = 67108864
const SAVE_ACTIONS = 134217728
const OPTIONS_ACTIONS = 268435456
const TITLE_ACTIONS = 536870912
const CODEC_ACTIONS = 1073741824
const INVENTORY_ACTIONS = 2147483648
const VISION_DEPENDENCIES = SCENE_MESHES | NATIVE_CONTEXT | SESSION_CONTEXT | DISC_IDENTITY | CINEMATIC_CONTEXT

var ready := false
var error := ""
var capabilities := COMMAND_RENDERING | DEBUG_TEXT | NATIVE_CONTEXT | SESSION_CONTEXT
var selected := 0
var selected_minor := 0
var session_token := PackedByteArray()
var public_id := PackedByteArray()

func configure_token(value: String) -> String:
	session_token = PackedByteArray()
	if value.length() != 32:
		return "MGS_GODOT_SESSION_TOKEN must contain 32 hexadecimal characters"
	for character in value:
		if character not in "0123456789abcdefABCDEF":
			return "MGS_GODOT_SESSION_TOKEN must contain 32 hexadecimal characters"
	session_token = value.hex_decode()
	return ""

func reply() -> PackedByteArray:
	var payload := PackedByteArray()
	if not ready or not error.is_empty():
		return payload
	payload.resize(12)
	payload.encode_u32(0, VERSION)
	payload.encode_u32(4, selected_minor)
	payload.encode_u32(8, selected)
	if selected & SESSION_CONTEXT:
		payload.append_array(public_id)
	return payload

func accept(operation: int, payload: PackedByteArray) -> String:
	if not error.is_empty():
		return error
	if operation != 1:
		if not ready:
			error = "Native renderer must send HELLO before command %d" % operation
		else:
			var required := SCENE_MESHES if operation in [9, 10] else DEBUG_TEXT if operation == 11 else NATIVE_CONTEXT if operation == 12 else COMMAND_RENDERING
			if operation in [13, 14]:
				required = RETAINED_PALETTES | SCENE_MESHES
			if operation == 15: required = MODEL_SOURCES | SCENE_MESHES
			if operation == 16: required = ELEVATOR_ACTORS | SCENE_MESHES | NATIVE_CONTEXT | SESSION_CONTEXT
			if operation == 17: required = GOGGLES_UI | VISION_DEPENDENCIES
			if operation == 18: required = STATUS_BARS | VISION_DEPENDENCIES
			if operation == 19: required = SUBTITLES | VISION_DEPENDENCIES
			if operation == 20: required = RADAR | VISION_DEPENDENCIES
			if operation == 21: required = INVENTORY | VISION_DEPENDENCIES
			if operation == 22: required = CODEC | VISION_DEPENDENCIES
			if operation == 23: required = OPTIONS | VISION_DEPENDENCIES
			if operation == 25: required = TITLE | VISION_DEPENDENCIES
			if operation == 24: required = SAVE_UI | VISION_DEPENDENCIES
			if operation == 26: required = DISPLAY | SCENE_MESHES | SESSION_CONTEXT
			if operation == 27: required = SAVE_ACTIONS | SAVE_UI | INPUT_CAPTURE | VISION_DEPENDENCIES
			if operation == 29: required = TITLE_ACTIONS | TITLE | INPUT_CAPTURE | VISION_DEPENDENCIES
			if operation == 30: required = CODEC_ACTIONS | CODEC | INPUT_CAPTURE | VISION_DEPENDENCIES
			if operation == 31: required = INVENTORY_ACTIONS | INVENTORY | INPUT_CAPTURE | VISION_DEPENDENCIES
			if operation == 28: required = OPTIONS_ACTIONS | OPTIONS | INPUT_CAPTURE | VISION_DEPENDENCIES
			if (selected & required) != required:
				error = "Command %d requires an unnegotiated capability 0x%x" % [operation, required]
		return error
	var available := capabilities
	if payload.size() == 40 and payload.decode_u32(8) < 30:
		available &= ~INVENTORY_ACTIONS
	if payload.size() == 40 and payload.decode_u32(8) < 29:
		available &= ~CODEC_ACTIONS
	if payload.size() == 40 and payload.decode_u32(8) < 28:
		available &= ~TITLE_ACTIONS
	if payload.size() == 40 and payload.decode_u32(8) < 27:
		available &= ~OPTIONS_ACTIONS
	if payload.size() == 40 and payload.decode_u32(8) < 26:
		available &= ~SAVE_ACTIONS
	if payload.size() == 40 and payload.decode_u32(8) < 25:
		available &= ~INPUT_CAPTURE
	if payload.size() == 40 and payload.decode_u32(8) < 24:
		available &= ~DISPLAY
	if payload.size() == 40 and payload.decode_u32(8) < 23:
		available &= ~TITLE
	if payload.size() == 40 and payload.decode_u32(8) < 22:
		available &= ~SAVE_UI
	if payload.size() == 40 and payload.decode_u32(8) < 21:
		available &= ~OPTIONS
	if payload.size() == 40 and payload.decode_u32(8) < 20:
		available &= ~CODEC
	if payload.size() == 40 and payload.decode_u32(8) < 19:
		available &= ~INVENTORY
	if payload.size() == 40 and payload.decode_u32(8) < 18:
		available &= ~RADAR
	if payload.size() == 40 and payload.decode_u32(8) < 17:
		available &= ~SUBTITLES
	if payload.size() == 40 and payload.decode_u32(8) < 16:
		available &= ~STATUS_BARS
	if payload.size() == 40 and payload.decode_u32(8) < 15:
		available &= ~GOGGLES_UI
	if payload.size() == 40 and payload.decode_u32(8) < 13:
		available &= ~THERMAL_VISION
	if payload.size() == 40 and payload.decode_u32(8) < 12:
		available &= ~VISION_CONTEXT
	if payload.size() == 40 and payload.decode_u32(8) < 11:
		available &= ~OBJECT_APPEARANCE
	if payload.size() == 40 and payload.decode_u32(8) < 10:
		available &= ~WORLD_SURFACES
	if payload.size() == 40 and payload.decode_u32(8) < 9:
		available &= ~WORLD_SNOW
	if payload.size() == 40 and payload.decode_u32(8) < 8:
		available &= ~INDEPENDENT_VIEW
	if payload.size() == 40 and payload.decode_u32(8) < 7:
		available &= ~CINEMATIC_CONTEXT
	if payload.size() == 40 and payload.decode_u32(8) < 6:
		available &= ~DISC_IDENTITY
	if payload.size() == 40 and payload.decode_u32(8) < 5:
		available &= ~ELEVATOR_ACTORS
	if payload.size() == 40 and payload.decode_u32(8) < 4:
		available &= ~MODEL_SOURCES
	if payload.size() == 40 and payload.decode_u32(8) < 3:
		available &= ~RETAINED_PALETTES
	if payload.size() == 40 and payload.decode_u32(8) < 2:
		available &= ~SESSION_CONTEXT
	if ready:
		error = "Duplicate native renderer HELLO; start a new session"
	elif payload.size() != 40:
		error = "Invalid native renderer HELLO length: expected 40, received %d; rebuild the native/Godot pair" % payload.size()
	elif session_token.size() != 16 or payload.slice(24, 40) != session_token:
		error = "Native renderer session token mismatch; launch both processes through the same session host"
	elif payload.decode_u32(0) != MAGIC:
		error = "Invalid native renderer HELLO magic"
	elif payload.decode_u32(4) != VERSION:
		error = "Incompatible native renderer protocol: expected %d, received %d" % [VERSION, payload.decode_u32(4)]
	elif payload.decode_u32(12) != VERTEX_STRIDE:
		error = "Incompatible native vertex stride: expected %d, received %d" % [VERTEX_STRIDE, payload.decode_u32(12)]
	elif payload.decode_u32(20) & ~payload.decode_u32(16):
		error = "Native renderer requires capabilities it did not offer"
	elif payload.decode_u32(20) & ~available:
		error = "Missing Godot renderer capabilities: 0x%x; check scene mode and the installed renderer" % (payload.decode_u32(20) & ~available)
	else:
		selected_minor = mini(MINOR, payload.decode_u32(8))
		selected = payload.decode_u32(16) & available
		if selected & INVENTORY_ACTIONS and (selected & (INVENTORY | INPUT_CAPTURE)) != (INVENTORY | INPUT_CAPTURE):
			error = "Inventory actions require inventory state and input capture"
			return error
		if selected & CODEC_ACTIONS and (selected & (CODEC | INPUT_CAPTURE)) != (CODEC | INPUT_CAPTURE):
			error = "Codec actions require Codec state and input capture"
			return error
		if selected & TITLE_ACTIONS and (selected & (TITLE | INPUT_CAPTURE)) != (TITLE | INPUT_CAPTURE):
			error = "Title actions require title state and input capture"
		if selected & OPTIONS_ACTIONS and (selected & (OPTIONS | INPUT_CAPTURE)) != (OPTIONS | INPUT_CAPTURE):
			error = "Options actions require Options UI and input capture"
			return error
		if selected & SAVE_ACTIONS and (selected & (SAVE_UI | INPUT_CAPTURE)) != (SAVE_UI | INPUT_CAPTURE):
			error = "Save actions require save UI and input capture"
			return error
		if selected & (DISPLAY | INPUT_CAPTURE) and (selected & (SCENE_MESHES | SESSION_CONTEXT)) != (SCENE_MESHES | SESSION_CONTEXT):
			error = "Display control requires scene and session capabilities"
			return error
		if selected & (GOGGLES_UI | STATUS_BARS | SUBTITLES | RADAR | INVENTORY | CODEC | OPTIONS | SAVE_UI | TITLE) and (selected & VISION_DEPENDENCIES) != VISION_DEPENDENCIES:
			error = "UI requires scene, session, disc and cinematic context capabilities"
			return error
		if selected & THERMAL_VISION and not selected & VISION_CONTEXT:
			error = "Thermal vision requires native vision context"
			return error
		if selected & VISION_CONTEXT and (selected & VISION_DEPENDENCIES) != VISION_DEPENDENCIES:
			error = "Vision context requires scene, session, disc and cinematic context capabilities"
			return error
		public_id = Crypto.new().generate_random_bytes(16)
		if public_id.size() != 16:
			error = "Cannot allocate native renderer session identity"
		else:
			ready = true
	return error
