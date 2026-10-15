extends RefCounted

var surfaces: Array[Dictionary] = []
var revision := 0
var initialized := false

func initialize(entry: Dictionary, count: int, original_geometry: bool) -> String:
	var height := maxi(1, ceili(count / 256.0))
	for index in entry.meshes.size():
		var mesh: MeshInstance3D = entry.meshes[index]
		if (not original_geometry or mesh.get_meta("mgs_custom_geometry", false)) and not mesh.get_meta("mgs_native_deformation", false): continue
		var source := mesh.mesh as ArrayMesh
		if source == null: return "Native deformation requires an original ArrayMesh"
		var dynamic := ArrayMesh.new()
		for surface in source.get_surface_count():
			var arrays := source.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
			if uv.size() != vertices.size(): return "Native deformation requires original corner coordinates"
			var corners := PackedInt32Array()
			for point in uv:
				var corner := int(point.x * 256) + int(point.y * height) * 256
				if not point.is_finite() or corner < 0 or corner >= count: return "Native deformation corner outside original model"
				corners.append(corner)
			dynamic.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays, [], {}, Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
			if RenderingServer.mesh_surface_get_format_vertex_stride(dynamic.surface_get_format(surface), vertices.size()) != 12:
				return "Native deformation requires uncompressed 3D positions"
			dynamic.surface_set_material(surface, source.surface_get_material(surface))
			surfaces.append({"mesh":dynamic, "surface":surface, "base":vertices, "corners":corners, "bounds":source.get_aabb(), "extent":0.0})
		mesh.mesh = dynamic
		if index < entry.metadata_meshes.size(): entry.metadata_meshes[index].mesh = dynamic
	initialized = true
	return ""

func apply(entry: Dictionary, data: PackedByteArray, version: int, original_geometry: bool = true) -> String:
	if revision == version: return ""
	if not initialized:
		var error := initialize(entry, data.size() / 12, original_geometry)
		if not error.is_empty(): return error
	var deltas := data.to_float32_array()
	var tree := Engine.get_main_loop() as SceneTree
	for surface in surfaces:
		var vertices: PackedVector3Array = surface.base.duplicate()
		var extent: float = surface.extent
		for vertex in vertices.size():
			var corner: int = surface.corners[vertex] * 3
			var delta := Vector3(deltas[corner], deltas[corner + 1], deltas[corner + 2])
			vertices[vertex] += delta
			extent = maxf(extent, delta.length())
		surface.mesh.surface_update_vertex_region(surface.surface, 0, vertices.to_byte_array())
		if tree != null: tree.call_group("mgs_mesh_deformation_listeners", "mesh_vertices_updated", surface.mesh, surface.surface, vertices, version)
		if extent > surface.extent:
			surface.extent = extent
			surface.mesh.custom_aabb = surface.mesh.custom_aabb.merge(surface.bounds.grow(extent))
	revision = version
	return ""
