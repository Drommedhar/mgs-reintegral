extends SceneTree

const Sources = preload("res://model_sources.gd")
const SESSION = "abcdef0123456789abcdef0123456789"
const ID = "mgs/integral-j/disc1/stage/s00a/0007.k"
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func packet() -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(72)
	data.encode_u32(0, 7)
	data.encode_u32(4, 10 * 65536 + 7)
	data.encode_u32(8, 100)
	for index in 4: data[16 + index] = "s00a".unicode_at(index)
	var session := SESSION.hex_decode()
	for index in 16: data[24 + index] = session[index]
	for index in 32: data[40 + index] = 0xab
	return data

func _initialize() -> void:
	var sources := Sources.new()
	sources.session_id = SESSION.hex_decode()
	var data := packet()
	check(sources.apply(data).is_empty(), "Valid declaration rejected")
	check(sources.validate(ID, {"sha256": "ab".repeat(32)}).is_empty(), "Matching content rejected")
	check("differs" in sources.validate(ID, {"sha256": "cd".repeat(32)}), "Different source accepted")
	check("Missing" in sources.validate("missing", {}), "Undeclared model accepted")
	var before := sources.models.duplicate(true)
	data[24] ^= 1
	check("session" in sources.apply(data) and sources.models == before, "Foreign session mutated registry")
	data = packet()
	data.encode_u32(12, 1)
	check("standalone" in sources.apply(data), "Nonzero standalone offset accepted")
	check(not sources.apply(data.slice(0, 71)).is_empty(), "Truncated packet accepted")
	data.encode_u32(4, 25 * 65536 + 8)
	check(sources.apply(data).is_empty(), "Archive declaration rejected")
	check("archive/subresource" in sources.validate(ID, {"sha256": "ab".repeat(32)}), "Archive was silently treated as standalone KMD")
	data = packet()
	data[16] = 47
	check(not sources.apply(data).is_empty(), "Invalid stage accepted")
	var scoped := Sources.new()
	scoped.session_id = SESSION.hex_decode()
	scoped.disc_identity = true
	data = packet()
	data.resize(76)
	data.encode_u32(72, 1)
	check(scoped.apply(data).is_empty(), "Disc-1 source rejected")
	data.encode_u32(72, 2)
	data[40] = 0xcd
	check(scoped.apply(data).is_empty() and scoped.models.size() == 2, "Same model hash on two discs collided")
	check(scoped.models[ID].sha256 == "ab".repeat(32), "Resident disc-1 source changed with disc-2 declaration")
	data.encode_u32(72, 3)
	check(not scoped.apply(data).is_empty() and scoped.models.size() == 2, "Invalid source disc accepted")
	for failure in failures: push_error(failure)
	print("MGS_MODEL_SOURCES_TEST failures=%d" % failures.size())
	quit(0 if failures.is_empty() else 1)
