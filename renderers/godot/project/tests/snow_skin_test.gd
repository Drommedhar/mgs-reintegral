extends SceneTree

var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	create_timer(30).timeout.connect(quit.bind(1))
	run.call_deferred()

func run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var skeleton := Skeleton3D.new()
	scene.add_child(skeleton)
	skeleton.position.x = 6
	skeleton.add_bone("first")
	skeleton.add_bone("second")
	skeleton.add_bone("unused")
	skeleton.set_bone_pose_position(0, Vector3(0,2,0))
	skeleton.set_bone_pose_position(1, Vector3(0,4,0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-1,0,-1),Vector3(1,0,-1),Vector3(0,0,1)])
	arrays[Mesh.ARRAY_BONES] = PackedInt32Array([0,0,0,0,0,0,0,0,0,0,0,0])
	arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array([1,0,0,0,1,0,0,0,1,0,0,0])
	var node := MeshInstance3D.new()
	node.mesh = ArrayMesh.new()
	node.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	node.skin = Skin.new()
	node.skin.add_bind(0, Transform3D.IDENTITY)
	node.skin.add_bind(1, Transform3D.IDENTITY)
	node.skin.add_bind(2, Transform3D.IDENTITY)
	node.skeleton = NodePath("..")
	skeleton.add_child(node)
	var collision := preload("res://addons/mgs_snow/collision_world.gd").new()
	collision.collect(scene)
	collision.prepare(100000)
	collision.sync()
	await physics_frame
	await physics_frame
	var hit: Dictionary = collision.cast(Vector3(6,6,0), Vector3(6,0,0))
	check(not hit.is_empty() and is_equal_approx(hit.get("position", Vector3.ZERO).y, 2), "Original rigid skin did not follow skeleton pose and world transform")
	arrays[Mesh.ARRAY_BONES][4] = 1
	node.mesh = ArrayMesh.new()
	node.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	collision.sync()
	collision.prepare(100000)
	collision.sync()
	await physics_frame
	await physics_frame
	hit = collision.cast(Vector3(6,6,0), Vector3(6,0,0))
	check(not hit.is_empty() and is_equal_approx(hit.get("position", Vector3.ZERO).y, 2.5), "Mixed-bone triangle was omitted or kept in its rest pose")
	skeleton.set_bone_pose_position(0, Vector3(0,3,0))
	collision.sync()
	await physics_frame
	await physics_frame
	hit = collision.cast(Vector3(6,6,0), Vector3(6,0,0))
	check(not hit.is_empty() and is_equal_approx(hit.get("position", Vector3.ZERO).y, 3.25), "Mixed-bone collision failed to update after motion")
	var rebuilds := [0]
	var shape: ConcavePolygonShape3D = collision.entries[node.get_instance_id()].collider.groups[-2].shape
	shape.changed.connect(func(): rebuilds[0] += 1)
	skeleton.set_bone_pose_position(2, Vector3(0,20,0))
	collision.sync()
	check(rebuilds[0] == 0, "An unused bone rebuilt the triangle collision shape")
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX].duplicate()
	for index in vertices.size(): vertices[index].y += 1
	collision.update_vertices(node.mesh, 0, vertices, 1)
	collision.sync()
	await physics_frame
	await physics_frame
	hit = collision.cast(Vector3(6,6,0), Vector3(6,0,0))
	check(not hit.is_empty() and is_equal_approx(hit.get("position", Vector3.ZERO).y, 4.25), "Native deformation did not update snow collision")
	collision.clear()
	scene.free()
	print("MGS_SNOW_SKIN_TEST failures=%d" % failures)
	quit(1 if failures else 0)
