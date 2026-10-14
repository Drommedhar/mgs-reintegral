@tool
extends RefCounted

static func copy(source: Material, lit: bool) -> Material:
	if not source is BaseMaterial3D: return source
	var material := source.duplicate() as BaseMaterial3D
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL if lit else BaseMaterial3D.SHADING_MODE_UNSHADED
	# Unshaded materials omit inactive PBR properties during Resource.duplicate().
	for property in material.get_property_list():
		if property.usage & PROPERTY_USAGE_STORAGE and property.name not in ["shading_mode", "resource_path", "script"]:
			material.set(property.name, source.get(property.name))
	return material

static func apply_mesh(mesh: MeshInstance3D, lit: bool) -> void:
	if mesh.material_override != null: mesh.material_override = copy(mesh.material_override, lit)
	for surface in mesh.mesh.get_surface_count():
		mesh.set_surface_override_material(surface, copy(mesh.get_active_material(surface), lit))
