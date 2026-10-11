@tool
extends RefCounted

static func parts(model: Node3D) -> Dictionary:
	var result := {}
	for mesh in model.find_children("mesh_*", "MeshInstance3D", true, false): result[str(mesh.name)] = mesh
	return result

static func material_values(material: Material) -> Dictionary:
	var values := {}
	if material == null: return values
	for property in material.get_property_list():
		if property.usage & PROPERTY_USAGE_STORAGE and property.name not in ["resource_path", "resource_name", "resource_local_to_scene", "script"]:
			values[property.name] = material.get(property.name)
	return values

static func apply(model: Node3D, edits: Dictionary) -> String:
	var meshes := parts(model)
	for name in edits:
		if not meshes.has(name) or not edits[name] is Dictionary: return "Unknown model part: " + str(name)
		var mesh: MeshInstance3D = meshes[name]
		var edit: Dictionary = edits[name]
		for key in edit:
			if key not in ["mesh", "transform", "surfaces"]: return "Unknown model edit: " + str(key)
		if edit.has("mesh"):
			if not edit.mesh is Mesh: return "Model edit requires a Mesh resource"
			mesh.mesh = edit.mesh
			mesh.set_meta("mgs_custom_geometry", true)
		if edit.has("transform"):
			if not edit.transform is Transform3D or not edit.transform.is_finite(): return "Invalid model part transform"
			mesh.transform = edit.transform
		var overrides := {}
		var inherit_albedo := []
		if not edit.get("surfaces", {}) is Dictionary: return "Model surfaces must be a dictionary"
		for surface in edit.get("surfaces", {}):
			if not surface is int or surface < 0 or surface >= mesh.mesh.get_surface_count(): return "Invalid model surface index"
			var change = edit.surfaces[surface]
			var material: Material = mesh.get_active_material(surface)
			if change is Material:
				material = change
			elif change is Dictionary and material is BaseMaterial3D:
				if not change.has("albedo_texture"): inherit_albedo.append(surface)
				material = material.duplicate()
				var allowed := {}
				for property in ClassDB.class_get_property_list(material.get_class()):
					if property.type != TYPE_NIL and property.name not in ["script", "resource_path"]: allowed[property.name] = true
				for property in change:
					if not allowed.has(property): return "Unknown material property: " + str(property)
					material.set(property, change[property])
			else: return "Model material edit requires material properties or a Material resource"
			mesh.set_surface_override_material(surface, material)
			overrides[surface] = material
		mesh.set_meta("mgs_material_edits", overrides)
		mesh.set_meta("mgs_inherit_albedo", inherit_albedo)
	model.set_meta("mgs_reference_model", true)
	return ""
