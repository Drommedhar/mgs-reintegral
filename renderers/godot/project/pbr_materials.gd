extends RefCounted

const SHADER = preload("res://reference_lit.gdshader")
const ReferenceShader = preload("res://reference_shader.gd")
const MAPS = ["albedo", "normal", "orm", "emission"]
var two_sided := Shader.new()
var definitions: Dictionary = {}
var textures: Dictionary = {}

func initialize(materials: Dictionary) -> String:
	definitions = materials
	two_sided = ReferenceShader.two_sided(SHADER)
	for definition in definitions.values():
		for map in MAPS:
			if not definition.has(map) or textures.has(definition[map]): continue
			var image := Image.load_from_file(definition[map])
			if image == null: return "Cannot decode PBR map: " + definition[map]
			image.generate_mipmaps()
			textures[definition[map]] = ImageTexture.create_from_image(image)
	return ""

func apply(material: ShaderMaterial, identity: String, double_sided: bool) -> void:
	var definition: Dictionary = definitions.get(identity, {})
	material.shader = two_sided if double_sided else SHADER
	material.set_shader_parameter("pbr_roughness", definition.get("roughness", 1.0 if definition.has("orm") else 0.8))
	material.set_shader_parameter("pbr_metallic", definition.get("metallic", 1.0 if definition.has("orm") else 0.0))
	material.set_shader_parameter("normal_scale", definition.get("normal_scale", 1.0))
	material.set_shader_parameter("emission_energy", definition.get("emission_energy", 1.0))
	for map in ["normal", "orm", "emission"]:
		material.set_shader_parameter("has_" + map, definition.has(map))
		if definition.has(map): material.set_shader_parameter(map + "_texture", textures[definition[map]])
