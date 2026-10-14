@tool
extends MeshInstance3D

@export_node_path("MeshInstance3D") var source_mesh: NodePath:
	set(value):
		source_mesh = value
		if is_node_ready(): rebuild.call_deferred()
@export var surface_index := 0:
	set(value):
		surface_index = value
		if is_node_ready(): rebuild.call_deferred()

func _validate_property(property: Dictionary) -> void:
	if property.name == "mesh": property.usage &= ~PROPERTY_USAGE_STORAGE

func _ready() -> void:
	rebuild.call_deferred()

func rebuild() -> void:
	var source := get_node_or_null(source_mesh) as MeshInstance3D
	if source == null or source.mesh == null or surface_index < 0 or surface_index >= source.mesh.get_surface_count():
		push_error("Puddle surface requires a valid source mesh and surface index: " + str(source_mesh))
		return
	var source_arrays := source.mesh.surface_get_arrays(surface_index)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices: PackedVector3Array = source_arrays[Mesh.ARRAY_VERTEX].duplicate()
	var normals := PackedVector3Array()
	var relative := global_transform.affine_inverse() * source.global_transform
	for index in vertices.size():
		vertices[index] = relative * vertices[index]
		vertices[index].y = 0.0
		normals.append(Vector3.UP)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = source_arrays[Mesh.ARRAY_TEX_UV]
	arrays[Mesh.ARRAY_INDEX] = source_arrays[Mesh.ARRAY_INDEX]
	var shape := ArrayMesh.new()
	shape.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = shape
	get_parent().configure()
