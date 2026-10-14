extends SceneTree

const World = preload("res://addons/mgs_snow/collision_world.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	create_timer(30).timeout.connect(quit.bind(1))
	run.call_deferred()

func plane(parent: Node, points: PackedVector3Array) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	parent.add_child(node)
	return node

func run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var floor_points := PackedVector3Array([Vector3(-2,1,-2),Vector3(2,1,-2),Vector3(-2,1,2),Vector3(2,1,-2),Vector3(2,1,2),Vector3(-2,1,2)])
	var floor := plane(scene, floor_points)
	var roof := plane(scene, floor_points)
	roof.position.y = 2
	var wall := plane(scene, PackedVector3Array([Vector3(4,0,-2),Vector3(4,4,-2),Vector3(4,0,2),Vector3(4,4,-2),Vector3(4,4,2),Vector3(4,0,2)]))
	var collision := World.new()
	collision.collect(scene)
	while not collision.pending.is_empty(): collision.prepare(100000)
	collision.sync()
	await physics_frame
	await physics_frame
	var hit: Dictionary = collision.cast(Vector3(0,5,0), Vector3.ZERO)
	check(not hit.is_empty() and is_equal_approx(hit.get("position", Vector3.ZERO).y, 3), "Reversed roof did not block downward snow")
	hit = collision.cast(Vector3.ZERO, Vector3(0,5,0))
	check(not hit.is_empty() and is_equal_approx(hit.get("position", Vector3.ZERO).y, 1), "Reverse-side floor collision is missing")
	hit = collision.cast(Vector3(3,2,0), Vector3(5,2,0))
	check(not hit.is_empty(), "Wind-driven flakes crossed a one-sided wall")
	roof.position.y = 3
	collision.sync()
	await physics_frame
	await physics_frame
	hit = collision.cast(Vector3(0,6,0), Vector3.ZERO)
	check(not hit.is_empty() and is_equal_approx(hit.get("position", Vector3.ZERO).y, 4), "Moving roof collision stayed at its previous transform")
	roof.hide()
	collision.sync()
	await physics_frame
	await physics_frame
	hit = collision.cast(Vector3(0,6,0), Vector3.ZERO)
	check(not hit.is_empty() and is_equal_approx(hit.get("position", Vector3.ZERO).y, 1), "Hidden geometry still blocked snow")
	roof.position.y = 4
	collision.sync()
	roof.show()
	collision.sync()
	await physics_frame
	await physics_frame
	hit = collision.cast(Vector3(0,6,0), Vector3.ZERO)
	check(not hit.is_empty() and is_equal_approx(hit.get("position", Vector3.ZERO).y, 5), "Reappearing geometry retained its hidden pose")
	collision.clear()
	floor.free()
	wall.free()
	scene.free()
	print("MGS_SNOW_COLLISION_TEST failures=%d" % failures)
	quit(1 if failures else 0)
