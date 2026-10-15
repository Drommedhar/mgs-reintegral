extends SceneTree

var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var source := MeshInstance3D.new()
	source.name = "Floor"
	source.mesh = PlaneMesh.new()
	source.position = Vector3(3, 1, 4)
	source.rotation.y = 0.4
	scene.add_child(source)
	source.owner = scene
	var puddle: Node3D = load("res://addons/mgs_water/puddle.tscn").instantiate()
	scene.add_child(puddle)
	puddle.owner = scene
	puddle.position = Vector3(2, 0.99, 3)
	var surface: MeshInstance3D = puddle.get_node("Surface")
	surface.set_script(load("res://addons/mgs_water/puddle_mesh.gd"))
	surface.source_mesh = surface.get_path_to(source)
	surface.rebuild()
	var original := source.mesh.surface_get_arrays(0)
	var derived := surface.mesh.surface_get_arrays(0)
	check(derived[Mesh.ARRAY_TEX_UV] == original[Mesh.ARRAY_TEX_UV], "Puddle mask UVs changed")
	for index in original[Mesh.ARRAY_VERTEX].size():
		var expected: Vector3 = source.to_global(original[Mesh.ARRAY_VERTEX][index])
		var actual: Vector3 = surface.to_global(derived[Mesh.ARRAY_VERTEX][index])
		check(Vector2(expected.x, expected.z).distance_to(Vector2(actual.x, actual.z)) < 0.0001 and is_equal_approx(actual.y, 0.99), "Puddle does not follow source footprint")
	var packed := PackedScene.new()
	check(packed.pack(scene) == OK, "Cannot pack puddle")
	var state := packed.get_state()
	for node in state.get_node_count():
		if str(state.get_node_path(node)).ends_with("Surface"):
			for property in state.get_node_property_count(node):
				check(state.get_node_property_name(node, property) != "mesh", "Derived preview geometry was serialized")
	scene.free()
	print("MGS_WATER_PUDDLE_MESH_TEST failures=", failures)
	quit(1 if failures else 0)
