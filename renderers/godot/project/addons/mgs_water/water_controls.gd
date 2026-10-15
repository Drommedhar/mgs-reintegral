@tool
extends RefCounted

const SHADERS = {"Surface": preload("surface.gdshader"), "Caustics": preload("caustics.gdshader")}
const PARAMETERS = {
	"waves/height": ["Surface", "wave_height"],
	"waves/size": ["Surface", "wavelength"],
	"waves/speed": ["Surface", "wave_speed"],
	"surface/roughness": ["Surface", "roughness"],
	"surface/refraction_amount": ["Surface", "refraction_strength"],
	"surface/intersection_fade_distance": ["Surface", "intersection_fade_distance"],
	"reflections/steps": ["Surface", "reflection_steps"],
	"reflections/ray_distance": ["Surface", "reflection_distance"],
	"reflections/thickness": ["Surface", "reflection_thickness"],
	"reflections/view_distance": ["Surface", "reflection_view_distance"],
	"reflections/fallback_color": ["Surface", "reflection_fallback"],
	"caustics/strength": ["Caustics", "strength"],
	"caustics/size": ["Caustics", "pattern_scale"],
	"caustics/speed": ["Caustics", "caustic_speed"],
	"caustics/color": ["Caustics", "caustic_color"],
	"coverage/enabled": ["Surface", "use_coverage_mask"],
	"coverage/texture": ["Surface", "coverage_mask"],
	"coverage/invert": ["Surface", "invert_coverage_mask"],
	"virtual_bottom/enabled": ["Surface", "virtual_bottom_enabled"],
	"virtual_bottom/texture": ["Surface", "bottom_texture"],
	"virtual_bottom/color": ["Surface", "bottom_color"],
	"virtual_bottom/depth": ["Surface", "bottom_depth"],
	"virtual_bottom/tile_size": ["Surface", "bottom_tile_size"],
}

static func properties() -> Array[Dictionary]:
	var uniforms := {}
	for child in SHADERS:
		for uniform in SHADERS[child].get_shader_uniform_list():
			uniforms[child + "/" + uniform.name] = uniform
	var result: Array[Dictionary] = []
	for path in PARAMETERS:
		var target: Array = PARAMETERS[path]
		var property: Dictionary = uniforms[target[0] + "/" + target[1]].duplicate()
		property.name = path
		property.usage = PROPERTY_USAGE_EDITOR
		if path == "caustics/size": property.hint_string = "0.02,10,0.01,or_greater,suffix:m"
		result.append(property)
	return result

static func read(region: Node, path: StringName) -> Variant:
	var target: Array = PARAMETERS[path]
	var child := region.get_node_or_null(NodePath(target[0])) as MeshInstance3D
	var value: Variant = null
	if child != null and child.material_override is ShaderMaterial:
		value = child.material_override.get_shader_parameter(target[1])
	if value == null: value = RenderingServer.shader_get_parameter_default(SHADERS[target[0]].get_rid(), target[1])
	return 1.0 / maxf(float(value), 0.0001) if path == "caustics/size" else value

static func apply(region: Node, path: StringName, value: Variant) -> void:
	var target: Array = PARAMETERS[path]
	var child := region.get_node_or_null(NodePath(target[0])) as MeshInstance3D
	if child == null: return
	if path == "caustics/size": value = 1.0 / maxf(float(value), 0.0001)
	child.material_override.set_shader_parameter(target[1], value)
