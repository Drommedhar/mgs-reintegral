@tool
extends RefCounted

const MeshCollider = preload("collision_mesh.gd")
var world := World3D.new()
var query := PhysicsRayQueryParameters3D.new()
var entries: Dictionary = {}
var by_mesh: Dictionary = {}
var bodies: Dictionary = {}
var pending: Array[WeakRef] = []
var exclusions: Array[Node] = []
var roots: Array[Node] = []
var warnings := PackedStringArray()

func _init() -> void:
	PhysicsServer3D.space_set_active(world.space, false)
	query.hit_back_faces = true
	query.collision_mask = 1

func collect(node: Node) -> void:
	if excluded(node): return
	if node is MeshInstance3D: pending.append(weakref(node))
	for child in node.get_children(): collect(child)

func excluded(node: Node) -> bool:
	var current := node
	while current != null:
		if current in exclusions or current.is_in_group("mgs_water_regions") or current.is_in_group("mgs_snow_volumes") or current.is_in_group("mgs_weather_exclude") or current.get_meta("mgs_runtime_metadata", false): return true
		current = current.get_parent()
	return false

func queue_node(node: Node) -> void:
	if not node is MeshInstance3D: return
	for source_root in roots:
		if is_instance_valid(source_root) and (node == source_root or source_root.is_ancestor_of(node)):
			pending.append(weakref(node))
			return

func prepare(budget_usec: int = 2000) -> void:
	var started := Time.get_ticks_usec()
	while not pending.is_empty() and Time.get_ticks_usec() - started < budget_usec:
		var source := pending.pop_front().get_ref() as MeshInstance3D
		if not is_instance_valid(source) or not source.is_inside_tree() or source.mesh == null or excluded(source) or entries.has(source.get_instance_id()): continue
		if source.mesh is ArrayMesh and source.mesh.get_blend_shape_count() > 0:
			warnings.append("Snow collision needs a separate mesh proxy for blend shapes: " + str(source.get_path()))
			continue
		var collider := MeshCollider.new()
		collider.initialize(source)
		collider.sync()
		if not by_mesh.has(source.mesh): by_mesh[source.mesh] = []
		by_mesh[source.mesh].append(collider)
		for group in collider.groups.values():
			var body := PhysicsServer3D.body_create()
			PhysicsServer3D.body_set_mode(body, PhysicsServer3D.BODY_MODE_STATIC)
			PhysicsServer3D.body_set_collision_layer(body, 0)
			PhysicsServer3D.body_set_collision_mask(body, 0)
			PhysicsServer3D.body_add_shape(body, group.shape.get_rid())
			PhysicsServer3D.body_set_space(body, world.space)
			group.body = body
			group.available = false
			bodies[body] = group
		entries[source.get_instance_id()] = {"source": weakref(source), "mesh": source.mesh, "collider": collider, "available": false}

func sync() -> void:
	for identity in entries.keys():
		var entry: Dictionary = entries[identity]
		var source := entry.source.get_ref() as MeshInstance3D
		if not is_instance_valid(source) or not source.is_inside_tree() or source.mesh != entry.mesh:
			remove(identity)
			if is_instance_valid(source): pending.append(weakref(source))
			continue
		var available := source.is_visible_in_tree() or source.is_in_group("mgs_snow_collision_proxy")
		var visibility_changed: bool = entry.available != available
		if not available and not visibility_changed: continue
		if available: entry.collider.sync()
		for group in entry.collider.groups.values():
			if available and group.get("last_transform") != group.transform:
				PhysicsServer3D.body_set_state(group.body, PhysicsServer3D.BODY_STATE_TRANSFORM, group.transform)
				group.last_transform = group.transform
			if visibility_changed:
				PhysicsServer3D.body_set_collision_layer(group.body, 1 if available else 0)
				group.available = available
		entry.available = available

func cast(from: Vector3, to: Vector3) -> Dictionary:
	if from.is_equal_approx(to): return {}
	query.from = from
	query.to = to
	return world.direct_space_state.intersect_ray(query)

func contact(body: RID, point: Vector3) -> Variant:
	if not bodies.has(body) or not bodies[body].available: return null
	return bodies[body].transform * point

func remove(identity: int) -> void:
	var mesh: Mesh = entries[identity].mesh
	by_mesh[mesh].erase(entries[identity].collider)
	if by_mesh[mesh].is_empty(): by_mesh.erase(mesh)
	for group in entries[identity].collider.groups.values():
		bodies.erase(group.body)
		PhysicsServer3D.free_rid(group.body)
	entries.erase(identity)

func update_vertices(mesh: Mesh, surface: int, vertices: PackedVector3Array, version: int) -> void:
	for collider in by_mesh.get(mesh, []): collider.update_vertices(surface, vertices, version)

func clear() -> void:
	for identity in entries.keys(): remove(identity)
	pending.clear()
