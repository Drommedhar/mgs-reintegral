@tool
extends RefCounted

const SPATIAL_PROPERTIES = ["position", "rotation", "scale", "visible"]

static func validate(layout: Dictionary, overrides: Variant) -> String:
	if not overrides is Dictionary: return "Original light overrides must be a dictionary"
	var identities: Array = layout.get("lights", []).map(func(light): return light.id)
	var prototype := OmniLight3D.new()
	var defaults := properties(prototype)
	prototype.free()
	for identity in overrides:
		if identity not in identities: return "Unknown original light: " + str(identity)
		if not overrides[identity] is Dictionary: return "Light properties must be a dictionary: " + str(identity)
		for property in overrides[identity]:
			var value = overrides[identity][property]
			if not defaults.has(property): return "Unsupported original light property: " + str(property)
			if not valid_value(value, defaults[property]): return "Invalid original light value: " + str(property)
			if property == "omni_range" and value <= 0: return "Original light range must be positive"
	return ""

static func valid_value(value: Variant, default: Variant) -> bool:
	if default == null: return value == null or value is Texture2D
	if default is float: return (value is float or value is int) and is_finite(value)
	if typeof(value) != typeof(default): return false
	if value is Vector3: return value.is_finite()
	if value is Color:
		return is_finite(value.r) and is_finite(value.g) and is_finite(value.b) and is_finite(value.a)
	return true

static func create(layout: Dictionary, overrides: Dictionary = {}) -> Node3D:
	var root := Node3D.new()
	root.name = "OriginalLights"
	for definition in layout.get("lights", []):
		var light := OmniLight3D.new()
		light.name = str(definition.id).replace(".", "_").replace("/", "_")
		light.set_meta("mgs_light_id", definition.id)
		light.editor_description = "Original map light " + str(definition.id)
		light.position = Vector3(definition.position[0], definition.position[1], definition.position[2]) / 1000.0
		light.light_color = Color(definition.color[0] / 255.0, definition.color[1] / 255.0, definition.color[2] / 255.0)
		# Native lighting uses a linear radial falloff and a separate box cutoff.
		light.omni_range = minf(definition.radius * 2.0, definition.extent) / 1000.0
		light.omni_attenuation = 1.0
		light.light_energy = 1.5
		light.shadow_enabled = true
		light.set_meta("mgs_light_defaults", properties(light))
		for property in overrides.get(definition.id, {}):
			light.set(property, overrides[definition.id][property])
		root.add_child(light)
	return root

static func properties(light: OmniLight3D) -> Dictionary:
	var result := {}
	for definition in light.get_property_list():
		var property: String = definition.name
		var lighting := property.begins_with("light_") or property.begins_with("shadow_") or property.begins_with("omni_") or property.begins_with("distance_fade_")
		if property in SPATIAL_PROPERTIES or (lighting and (definition.usage & PROPERTY_USAGE_STORAGE)):
			result[property] = light.get(property)
	return result
