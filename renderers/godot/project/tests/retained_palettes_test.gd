extends SceneTree

const Store = preload("res://retained_palettes.gd")
const SESSION = "abcdef0123456789abcdef0123456789"
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func record(action: int, previous: int, revision: int, data: PackedByteArray) -> PackedByteArray:
	var payload := PackedInt32Array([action, 1, 1, previous, revision, data.size()]).to_byte_array()
	payload.append_array(SESSION.hex_decode())
	payload.append_array(data)
	return payload

func _initialize() -> void:
	var store := Store.new()
	store.session_id = SESSION.hex_decode()
	var first := PackedByteArray([1, 2, 3, 4])
	check(store.apply(record(1, 0, 1, first)).is_empty(), "Create failed")
	check(store.resolve(1, 1, 1, 4) == first, "Created data differs")
	for invalid in [record(1, 0, 1, first), record(2, 0, 2, first), record(2, 1, 3, first),
		record(3, 0, 0, PackedByteArray()), record(3, 1, 0, first), record(2, 1, 2, PackedByteArray([1]))]:
		check(not store.apply(invalid).is_empty(), "Invalid resource transition accepted")
		check(store.resolve(1, 1, 1, 4) == first and store.resident_bytes == 4, "Failed operation changed retained data")
	var foreign := record(2, 1, 2, first)
	foreign[24] ^= 1
	check(not store.apply(foreign).is_empty(), "Foreign session accepted")
	var second := PackedByteArray([5, 6, 7, 8])
	check(store.apply(record(2, 1, 2, second)).is_empty(), "Update failed")
	check(store.resolve(1, 1, 1, 4).is_empty(), "Stale reference resolved")
	check(store.resolve(1, 1, 2, 8).is_empty(), "Wrong resource size resolved")
	check(store.resolve(1, 1, 2, 4) == second, "Updated bytes differ")
	check(store.received_bytes == 8 and store.updates == 2 and store.resident_bytes == 4, "Resource counters incorrect")
	check(store.apply(record(3, 2, 0, PackedByteArray())).is_empty(), "Retirement failed")
	check(store.resident_bytes == 0 and store.resolve(1, 1, 2, 4).is_empty(), "Retired resource remains live")
	check(not store.apply(record(2, 2, 3, first)).is_empty(), "Retired resource resurrected by update")
	var deformation := record(1, 0, 1, PackedFloat32Array([0.1, -0.2, 0.3]).to_byte_array())
	deformation.encode_u32(8, 3)
	check(not store.apply(deformation).is_empty(), "Unnegotiated deformation accepted")
	store.deformation_supported = true
	check(store.apply(deformation).is_empty(), "Negotiated deformation rejected")
	var invalid := deformation.duplicate()
	invalid.encode_u32(0, 2)
	invalid.encode_u32(12, 1)
	invalid.encode_u32(16, 2)
	invalid.encode_float(40, NAN)
	check(not store.apply(invalid).is_empty(), "Non-finite deformation accepted")
	check(store.resolve(1, 3, 1, 12) == deformation.slice(40), "Rejected deformation damaged live data")
	var live := record(1, 0, 1, PackedFloat32Array([10.5, 20.5, 33, 512]).to_byte_array())
	live.encode_u32(8, 4)
	check(not store.apply(live).is_empty(), "Unnegotiated live texture accepted")
	store.live_textures_supported = true
	check(store.apply(live).is_empty(), "Negotiated live texture rejected")
	check(store.resolve(1, 4, 1, 16) == live.slice(40), "Live texture descriptor changed")
	for invalid_value in [NAN, INF, -1.0, 256.5]:
		var malformed := live.duplicate()
		malformed.encode_u32(0, 2)
		malformed.encode_u32(12, 1)
		malformed.encode_u32(16, 2)
		malformed.encode_float(40, invalid_value)
		check(not store.apply(malformed).is_empty(), "Invalid live texture coordinate accepted")
	print("RETAINED PALETTE TEST failures=%d" % failures)
	quit(0 if failures == 0 else 1)
