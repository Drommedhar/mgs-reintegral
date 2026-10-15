@tool
extends RefCounted

const SHADER = preload("res://reference_lit.gdshader")
const ReferenceShader = preload("res://reference_shader.gd")
const MAPS = ["albedo", "normal", "orm", "emission"]
var two_sided := Shader.new()
var definitions: Dictionary = {}
var textures: Dictionary = {}

func initialize(materials: Dictionary) -> String:
	definitions = materials
	textures.clear()
	two_sided = ReferenceShader.two_sided(SHADER)
	for definition in definitions.values():
		for map in MAPS:
			if not definition.has(map) or textures.has(definition[map]): continue
			var image := Image.load_from_file(definition[map])
			if image == null: return "Cannot decode PBR map: " + definition[map]
			image.generate_mipmaps(map == "normal", map == "albedo", 0.5)
			textures[definition[map]] = ImageTexture.create_from_image(image)
	return ""

func factors(identity: String) -> Dictionary:
	var definition: Dictionary = definitions.get(identity, {})
	return {"roughness":definition.get("roughness", 1.0 if definition.has("orm") else 0.8),
		"metallic":definition.get("metallic", 1.0 if definition.has("orm") else 0.0),
		"normal_scale":definition.get("normal_scale", 1.0), "emission_energy":definition.get("emission_energy", 1.0)}

func apply(material: ShaderMaterial, identity: String, double_sided: bool) -> void:
	var definition: Dictionary = definitions.get(identity, {})
	var values := factors(identity)
	material.shader = two_sided if double_sided else SHADER
	material.set_shader_parameter("pbr_roughness", values.roughness)
	material.set_shader_parameter("pbr_metallic", values.metallic)
	material.set_shader_parameter("normal_scale", values.normal_scale)
	material.set_shader_parameter("emission_energy", values.emission_energy)
	for map in ["normal", "orm", "emission"]:
		material.set_shader_parameter("has_" + map, definition.has(map))
		if definition.has(map): material.set_shader_parameter(map + "_texture", textures[definition[map]])

func apply_standard(material: StandardMaterial3D, identity: String) -> void:
	var definition: Dictionary = definitions.get(identity, {})
	var values := factors(identity)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.roughness = values.roughness
	material.metallic = values.metallic
	material.normal_scale = values.normal_scale
	material.normal_enabled = definition.has("normal")
	if material.normal_enabled: material.normal_texture = textures[definition.normal]
	material.ao_enabled = definition.has("orm")
	if material.ao_enabled:
		material.ao_texture = textures[definition.orm]
		material.roughness_texture = textures[definition.orm]
		material.metallic_texture = textures[definition.orm]
		material.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		material.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	material.emission_enabled = definition.has("emission")
	if material.emission_enabled:
		material.emission = Color.WHITE
		material.emission_texture = textures[definition.emission]
		material.emission_energy_multiplier = values.emission_energy
	if definition.has("albedo"): material.albedo_texture = textures[definition.albedo]
