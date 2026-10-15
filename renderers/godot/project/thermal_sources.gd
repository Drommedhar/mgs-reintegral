extends RefCounted

const LAYER = 1 << 17
const SHADER = preload("res://thermal_mask.gdshader")
var authored: Dictionary = {}
var copies: Dictionary = {}

func register(mesh: MeshInstance3D, heat: float) -> String:
	if not is_instance_valid(mesh) or mesh.mesh == null: return "Thermal source requires a MeshInstance3D with geometry"
	if not mesh.is_inside_tree(): return "Add the thermal source to the scene tree before registering it"
	if not is_finite(heat) or heat < 0 or heat > 1: return "Thermal source heat must be finite in [0,1]"
	authored[mesh] = heat
	return ""

func unregister(mesh: MeshInstance3D) -> void:
	authored.erase(mesh)

func synchronize(instances: Dictionary, active: bool, empty_surface: Material, camera_mask: int = 0xfffff) -> void:
	var sources := {}
	if active:
		for entry in instances.values():
			if entry.get("thermal", false):
				for mesh in entry.meshes: sources[mesh] = 1.0
		for mesh in authored.keys():
			if is_instance_valid(mesh): sources[mesh] = authored[mesh]
			else: authored.erase(mesh)
	for mesh in sources.keys():
		if not is_instance_valid(mesh) or not mesh.is_inside_tree() or mesh.mesh == null: sources.erase(mesh)
	for mesh in copies.keys():
		if not is_instance_valid(mesh) or not sources.has(mesh):
			if is_instance_valid(copies[mesh]):
				copies[mesh].hide()
				copies[mesh].queue_free()
			copies.erase(mesh)
	for mesh in sources:
		if not copies.has(mesh):
			var copy := MeshInstance3D.new()
			copy.name = "thermal_" + str(mesh.name)
			copy.layers = LAYER
			copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			copy.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			copy.set_meta("mgs_runtime_metadata", true)
			var material := ShaderMaterial.new()
			material.shader = SHADER
			copy.set_meta("heat_material", material)
			mesh.get_parent().add_child(copy)
			copies[mesh] = copy
		var copy: MeshInstance3D = copies[mesh]
		if copy.get_parent() != mesh.get_parent(): copy.reparent(mesh.get_parent(), false)
		if copy.mesh != mesh.mesh: copy.mesh = mesh.mesh
		copy.skin = mesh.skin
		copy.skeleton = mesh.skeleton
		copy.top_level = mesh.top_level
		copy.transform = mesh.transform
		for index in mesh.get_blend_shape_count(): copy.set_blend_shape_value(index, mesh.get_blend_shape_value(index))
		copy.visible = mesh.visible and (mesh.layers & camera_mask) != 0 and mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		for property in ["custom_aabb", "extra_cull_margin", "visibility_range_begin", "visibility_range_end", "visibility_range_begin_margin", "visibility_range_end_margin", "visibility_range_fade_mode"]:
			copy.set(property, mesh.get(property))
		var material: ShaderMaterial = copy.get_meta("heat_material")
		material.set_shader_parameter("heat", sources[mesh])
		# Empty original surfaces must remain empty in the heat pass.
		if mesh.material_override == empty_surface: copy.hide()
		for surface in mesh.mesh.get_surface_count():
			var target: Material = empty_surface if mesh.get_active_material(surface) == empty_surface else material
			if copy.get_surface_override_material(surface) != target: copy.set_surface_override_material(surface, target)
