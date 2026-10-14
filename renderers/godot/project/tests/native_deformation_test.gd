extends SceneTree

const Deformation = preload("res://native_deformation.gd")
var failures := 0

class CollisionListener extends Node:
	var received := PackedVector3Array()
	func mesh_vertices_updated(_mesh: Mesh, _surface: int, vertices: PackedVector3Array, _version: int) -> void:
		received = vertices

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var listener := CollisionListener.new()
	root.add_child(listener)
	listener.add_to_group("mgs_mesh_deformation_listeners")
	var mesh := MeshInstance3D.new()
	mesh.mesh = ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var original := PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	arrays[Mesh.ARRAY_VERTEX] = original
	arrays[Mesh.ARRAY_TEX_UV2] = PackedVector2Array([Vector2(0.5 / 256, 0.5), Vector2(1.5 / 256, 0.5), Vector2(2.5 / 256, 0.5)])
	mesh.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var unchanged := mesh.mesh
	var metadata := MeshInstance3D.new()
	metadata.mesh = mesh.mesh
	var custom := MeshInstance3D.new()
	custom.mesh = BoxMesh.new()
	custom.set_meta("mgs_custom_geometry", true)
	var entry := {"meshes":[mesh, custom], "metadata_meshes":[metadata]}
	var deformation := Deformation.new()
	var deltas := PackedFloat32Array([0, 0.5, 0, 0, 0, 0, 0, 0, -1]).to_byte_array()
	check(deformation.apply(entry, deltas, 1).is_empty(), "Original deformation rejected")
	check(listener.received[0].is_equal_approx(Vector3(0, 0.5, 0)), "Visual collision listeners did not receive native CPU deformation")
	check(mesh.mesh != unchanged and metadata.mesh == mesh.mesh, "Instance and depth geometry do not share deformation")
	check(custom.mesh is BoxMesh, "Custom replacement received original corner deformation")
	check(deformation.apply(entry, deltas, 1).is_empty() and deformation.revision == 1, "Unchanged revision failed")
	RenderingServer.force_draw(false)
	var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	check(vertices[0].is_equal_approx(Vector3(0, 0.5, 0)) and vertices[2].is_equal_approx(Vector3(0, 1, -1)), "GPU vertex positions differ from native deltas")
	check(unchanged.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == original, "Deformation changed the shared original template")
	var zero := PackedByteArray()
	zero.resize(36)
	check(deformation.apply(entry, zero, 2).is_empty(), "Restoration failed")
	RenderingServer.force_draw(false)
	check(mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == original, "Restoration accumulated deformation")
	check(mesh.mesh.custom_aabb.has_point(Vector3(0, 1, -1)), "Deformed geometry can be culled by original bounds")
	mesh.free()
	metadata.free()
	custom.free()
	listener.free()
	print("MGS_NATIVE_DEFORMATION_TEST failures=%d" % failures)
	quit(1 if failures else 0)
