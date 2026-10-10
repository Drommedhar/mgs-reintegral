extends SceneTree

const Registry = preload("res://mod_registry.gd")
const Contract = preload("res://model_contract.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func rig() -> Node3D:
	var root := Node3D.new()
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton"
	root.add_child(skeleton)
	skeleton.add_bone("part_000")
	skeleton.add_bone("part_001")
	skeleton.set_bone_parent(1, 0)
	skeleton.set_bone_rest(1, Transform3D(Basis.IDENTITY, Vector3(1, 0, 0)))
	var mesh := MeshInstance3D.new()
	mesh.name = "mesh_000"
	mesh.skin = Skin.new()
	mesh.skin.add_bind(0, Transform3D.IDENTITY)
	mesh.skeleton = NodePath("../Skeleton")
	root.add_child(mesh)
	return root

func _initialize() -> void:
	check(Registry.asset_path("res://mods/test", "../escape.png").is_empty(), "Parent path traversal accepted")
	check(Registry.asset_path("res://mods/test", "C:/escape.png").is_empty(), "Absolute replacement accepted")
	check(Registry.asset_path("res://mods/test", "textures/test.png") == "res://mods/test/textures/test.png", "Valid replacement path rejected")
	var reference := rig()
	var replacement := rig()
	check(Contract.validate(reference, replacement).is_empty(), "Identical original rig rejected")
	replacement.get_node("mesh_000").skin.set_bind_pose(0, Transform3D(Basis.IDENTITY, Vector3.ONE))
	check(not Contract.validate(reference, replacement).is_empty(), "Changed skin bind accepted")
	replacement.get_node("mesh_000").skin.set_bind_pose(0, Transform3D.IDENTITY)
	replacement.get_node("Skeleton").set_bone_parent(1, -1)
	check(not Contract.validate(reference, replacement).is_empty(), "Changed parent accepted")
	replacement.get_node("Skeleton").set_bone_parent(1, 0)
	replacement.get_node("Skeleton").set_bone_rest(1, Transform3D.IDENTITY)
	check(not Contract.validate(reference, replacement).is_empty(), "Changed rest pose accepted")
	reference.free()
	replacement.free()
	var directory := "user://mgs-mod-contract-test"
	DirAccess.make_dir_recursive_absolute(directory)
	FileAccess.open(directory.path_join("texture.png"), FileAccess.WRITE).store_8(0)
	var first := {"schema": 1, "id": "first", "priority": 1,
		"replacements": {"fixture": {"path": "texture.png"}}}
	var second := first.duplicate(true)
	second.id = "second"
	second.priority = 2
	for item in [first, second]:
		FileAccess.open(directory.path_join(item.id + ".json"), FileAccess.WRITE).store_string(JSON.stringify(item))
	var registry := Registry.new()
	var error := registry.configure({"fixture": {"kind": "texture"}}, [directory.path_join("second.json"), directory.path_join("first.json")])
	check(error.is_empty(), error)
	check(registry.replacements.fixture.mod == "second", "CLI order overrode manifest priority")
	print("MGS_MOD_CONTRACT_TEST failures=%d" % failures)
	quit(1 if failures else 0)
