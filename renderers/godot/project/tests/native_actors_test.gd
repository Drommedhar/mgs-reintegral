extends SceneTree

const Actors = preload("res://native_actors.gd")
const SESSION = "abcdef0123456789abcdef0123456789"
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func packet() -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(136)
	var words := [1,1,1,1,3,8,5,0xb15b,1,0x2abc,20,3,6*65536+0xea54,5981]
	for i in words.size(): bytes.encode_u32(i*4, words[i])
	for i in 4: bytes[56+i] = "s00a".unicode_at(i)
	bytes.encode_float(96, 1)
	bytes.encode_float(100, 4)
	bytes.encode_float(104, -28.8)
	bytes.encode_s32(108, 225)
	bytes.encode_s32(112, 450)
	bytes.encode_u32(116, 1)
	var session := SESSION.hex_decode()
	for i in 16: bytes[120+i] = session[i]
	return bytes

func _initialize() -> void:
	run.call_deferred()

func check_resolution(actors: Node3D, bytes: PackedByteArray) -> void:
	var target := {"stage":"s00a", "script":6*65536+0xea54, "command_offset":5981,
		"provider":0x2abc, "script_sha256": "0".repeat(64)}
	actors.set_epoch(3)
	var resolved: Dictionary = actors.resolve_declaration(target)
	check(resolved.status == "available" and resolved.actor.slot == 1, "Late declaration lookup failed")
	resolved.actor.identity.name = 7
	check(actors.actors[1].identity.name == 0xb15b, "Resolved identity was mutable")
	check(actors.resolve_declaration(JSON.parse_string(JSON.stringify(target))).status == "available", "Serialized target rejected")
	var changed := target.duplicate()
	changed.script_sha256 = "1".repeat(64)
	check(actors.resolve_declaration(changed).status == "inactive", "Different script revision matched")
	changed = target.duplicate()
	changed.command_offset = 0xffffffff
	check(actors.resolve_declaration(changed).status == "invalid", "Unresolved offset allowed as target")
	changed = target.duplicate()
	changed.command_offset = 0.5
	check(actors.resolve_declaration(changed).status == "invalid", "Fractional declaration offset accepted")
	changed = target.duplicate()
	changed.model = "6da3"
	check(actors.resolve_declaration(changed).status == "invalid", "Unsupported selector silently ignored")
	var second := bytes.duplicate()
	second.encode_u32(8, 2)
	second.encode_u32(20, 9)
	second.encode_u32(52, 1234)
	check(actors.apply(second, {"epoch":3}).is_empty(), "Second actor rejected")
	check(actors.resolve_declaration(target).actor.slot == 1, "Same actor name confused declarations")
	var third := bytes.duplicate()
	third.encode_u32(8, 3)
	third.encode_u32(20, 10)
	check(actors.apply(third, {"epoch":3}).is_empty(), "Repeated declaration spawn rejected")
	resolved = actors.resolve_declaration(target)
	check(resolved.status == "ambiguous" and not resolved.has("actor"), "Repeated declaration picked an arbitrary incarnation")
	var api := preload("res://visual_mod_api.gd").new()
	api.native_actors = actors
	api.native_context_updated.connect(func():
		check(actors.current_epoch == 4 and not actors.actors[1].body.visible, "Context signal exposed previous-epoch visuals")
		check(api.resolve_native_actor(target).status == "inactive", "Context signal resolved previous-epoch actor"))
	api.publish_native_context({"epoch":4})
	api.free()
	check(actors.resolve_declaration(target).status == "inactive", "Previous scene resolved as active")
	for other in [second, third]:
		other.encode_u32(4, 3)
		check(actors.apply(other, {"epoch":4}).is_empty(), "Lookup fixture retirement failed")
	actors.set_epoch(3)
	check(actors.resolve_declaration(target).status == "available", "Retired duplicate still makes target ambiguous")

func run() -> void:
	check_wall()
	var actors := Actors.new()
	root.add_child(actors)
	actors.session_id = SESSION.hex_decode()
	var context := {"epoch": 3}
	var bytes := packet()
	check(actors.apply(bytes, context).is_empty(), "Spawn rejected")
	check_resolution(actors, bytes)
	var body: Node3D = actors.actors[1].body
	var child := Node3D.new()
	child.position = Vector3(0, 0.5, 0)
	body.add_child(child)
	check(child.global_position.is_equal_approx(Vector3(1,-4.5,28.8)), "Native world/child offset conversion incorrect")
	check(not actors.apply(bytes, context).is_empty(), "Duplicate spawn accepted")
	var snapshot := actors.snapshot()
	snapshot[0].identity.name = 1
	check(actors.actors[1].identity.name == 0xb15b, "Mod mutated authoritative identity")
	bytes.encode_u32(4, 2)
	bytes.encode_float(100, 3)
	check(actors.apply(bytes, context).is_empty() and child.global_position.is_equal_approx(Vector3(1,-3.5,28.8)), "Attachment did not follow update")
	var structural := Node3D.new()
	root.add_child(structural)
	structural.transform = Transform3D(Basis(Vector3.UP, PI / 2).scaled(Vector3(2,3,4)), Vector3(10,0,0))
	body.reparent(structural)
	check(actors.apply(bytes, context).is_empty() and child.global_position.is_equal_approx(Vector3(1,-3.5,28.8)), "Structural parent changed native world pose")
	structural.scale = Vector3.ZERO
	check("singular" in actors.apply(bytes, context), "Singular parent accepted")
	structural.scale = Vector3.ONE
	bytes[120] ^= 1
	check(not actors.apply(bytes, context).is_empty() and actors.actors[1].body == body, "Foreign session accepted")
	bytes[120] ^= 1
	actors.set_epoch(4)
	check(not body.visible, "Old-epoch body still visible")
	bytes.encode_u32(4, 3)
	check(actors.apply(bytes, {"epoch":4}).is_empty() and actors.actors.is_empty() and not is_instance_valid(child), "Retirement left attachment alive")
	bytes = packet()
	check(not actors.apply(bytes, context).is_empty(), "Stale generation accepted")
	bytes.encode_u32(12, 2)
	check(actors.apply(bytes, context).is_empty(), "New generation rejected")
	actors.free()
	structural.free()
	for failure in failures: push_error(failure)
	print("MGS_NATIVE_ACTORS_TEST failures=%d" % failures.size())
	quit(0 if failures.is_empty() else 1)

func check_wall() -> void:
	var actors := Actors.new()
	root.add_child(actors)
	actors.session_id = SESSION.hex_decode()
	var bytes := packet()
	bytes.encode_u32(36, 0xec77)
	bytes.encode_u32(44, 0)
	bytes.encode_u32(108, 0)
	bytes.encode_u32(112, 0)
	check(not actors.apply(bytes, {"epoch":3}).is_empty(), "Wall accepted without protocol32 negotiation")
	actors.generic_providers = true
	check(actors.apply(bytes, {"epoch":3}).is_empty(), "Wall declaration rejected")
	check(actors.actors[1].state == {"visible":true}, "Wall received fictitious elevator state")
	bytes.encode_u32(4, 2)
	bytes.encode_u32(116, 0)
	check(actors.apply(bytes, {"epoch":3}).is_empty() and not actors.actors[1].state.visible, "Wall visibility update lost")
	bytes.encode_u32(4, 3)
	check(actors.apply(bytes, {"epoch":3}).is_empty() and actors.actors.is_empty(), "Wall retirement failed")
	actors.free()
