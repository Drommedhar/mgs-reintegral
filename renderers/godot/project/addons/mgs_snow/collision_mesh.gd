@tool
extends RefCounted

var surfaces: Array[Array] = []
var groups: Dictionary = {}
var skin: Skin
var skeleton: Skeleton3D
var source: MeshInstance3D
var revision := -1
var geometry_revision := 0
var used_binds: Dictionary = {}

func initialize(mesh_node: MeshInstance3D) -> void:
	source = mesh_node
	skin = source.skin
	skeleton = source.get_node_or_null(source.skeleton) as Skeleton3D if skin != null else null
	for surface in source.mesh.get_surface_count():
		var arrays := source.mesh.surface_get_arrays(surface)
		var index := surfaces.size()
		surfaces.append(arrays)
		if source.mesh is ArrayMesh and source.mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES: continue
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if indices.is_empty():
			for vertex in vertices.size(): indices.append(vertex)
		for triangle in range(0, indices.size() - 2, 3):
			var bone := rigid_bone(arrays, indices[triangle])
			if rigid_bone(arrays, indices[triangle + 1]) != bone or rigid_bone(arrays, indices[triangle + 2]) != bone: bone = -2
			if not groups.has(bone): groups[bone] = {"references": [], "shape": ConcavePolygonShape3D.new(), "transform": Transform3D.IDENTITY, "poses": []}
			for corner in 3: groups[bone].references.append(Vector2i(index, indices[triangle + corner]))
	for group in groups.values(): group.shape.backface_collision = true
	for bone in groups:
		if bone >= 0: used_binds[bone] = true
		elif bone == -2:
			for reference in groups[bone].references: collect_binds(surfaces[reference.x], reference.y)

func collect_binds(arrays: Array, vertex: int) -> void:
	if arrays[Mesh.ARRAY_WEIGHTS] == null: return
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var stride := weights.size() / (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	for influence in stride:
		var offset := vertex * stride + influence
		if weights[offset] > 0: used_binds[bones[offset]] = true

func rigid_bone(arrays: Array, vertex: int) -> int:
	if skeleton == null or arrays[Mesh.ARRAY_WEIGHTS] == null: return -1
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	if weights.is_empty(): return -1
	var stride := weights.size() / (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var single := -2
	for influence in stride:
		var weight := weights[vertex * stride + influence]
		if is_zero_approx(weight): continue
		if not is_equal_approx(weight, 1.0) or single != -2: return -2
		single = bones[vertex * stride + influence]
	return single

func poses() -> Dictionary:
	var result := {}
	if not is_instance_valid(skeleton): return result
	for bind in used_binds:
		var name := skin.get_bind_name(bind)
		var bone := skeleton.find_bone(name) if not name.is_empty() else skin.get_bind_bone(bind)
		result[bind] = skeleton.get_bone_global_pose(bone) * skin.get_bind_pose(bind)
	return result

func skinned_vertex(arrays: Array, vertex: int, transforms: Dictionary) -> Vector3:
	var point: Vector3 = arrays[Mesh.ARRAY_VERTEX][vertex]
	if arrays[Mesh.ARRAY_WEIGHTS] == null: return point
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	if transforms.is_empty() or weights.is_empty(): return point
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var stride := weights.size() / (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var result := Vector3.ZERO
	for influence in stride:
		var offset := vertex * stride + influence
		if weights[offset] > 0: result += (transforms[bones[offset]] * point) * weights[offset]
	return result

func sync() -> void:
	var transforms := poses()
	for bone in groups:
		var group: Dictionary = groups[bone]
		if geometry_revision != revision or (bone == -2 and transforms != group.poses):
			var faces := PackedVector3Array()
			for reference in group.references:
				var arrays: Array = surfaces[reference.x]
				faces.append(skinned_vertex(arrays, reference.y, transforms) if bone == -2 else arrays[Mesh.ARRAY_VERTEX][reference.y])
			group.shape.set_faces(faces)
			group.poses = transforms
		group.transform = skeleton.global_transform if bone != -1 and is_instance_valid(skeleton) else source.global_transform
		if bone >= 0: group.transform *= transforms[bone]
	revision = geometry_revision

func update_vertices(surface: int, vertices: PackedVector3Array, version: int) -> void:
	if surface >= surfaces.size(): return
	surfaces[surface][Mesh.ARRAY_VERTEX] = vertices
	geometry_revision = version
