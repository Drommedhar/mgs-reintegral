@tool
extends RefCounted

const SNOW = "mgs/effects/snow"
const INPUTS = {"geometry_data": TYPE_OBJECT, "albedo_texture": TYPE_OBJECT, "mask_texture": TYPE_OBJECT, "quad_count": TYPE_INT, "screen_sized": TYPE_BOOL}
var definitions: Dictionary = {}
var textures: Dictionary = {}

func prepare_textures(path: String, visited: Dictionary) -> String:
	if visited.has(path): return ""
	visited[path] = true
	for dependency in ResourceLoader.get_dependencies(path):
		var resource_path: String = dependency.split("::")[-1]
		if resource_path.get_extension().to_lower() in ["png", "webp"]:
			if textures.has(resource_path): continue
			var image := Image.load_from_file(resource_path)
			if image == null: return "Cannot decode effect texture: " + resource_path
			image.generate_mipmaps()
			var texture := ImageTexture.create_from_image(image)
			texture.take_over_path(resource_path)
			textures[resource_path] = texture
		else:
			var error := prepare_textures(resource_path, visited)
			if not error.is_empty(): return error
	return ""

static func validate_shader(shader: Shader) -> String:
	if shader == null or shader.get_mode() != Shader.MODE_SPATIAL: return "Effect requires a spatial shader"
	var uniforms := {}
	for uniform in shader.get_shader_uniform_list(): uniforms[uniform.name] = uniform.type
	for input in INPUTS:
		if uniforms.get(input) != INPUTS[input]: return "Effect shader is missing the native input: " + input
	return ""

func initialize(entries: Dictionary) -> String:
	definitions.clear()
	textures.clear()
	for identity in entries:
		var entry: Dictionary = entries[identity]
		var texture_error := prepare_textures(entry.material, {})
		if not texture_error.is_empty(): return texture_error
		var material := load(entry.material) as ShaderMaterial
		var depth := load(entry.depth_shader) as Shader
		if material == null: return "Effect requires a ShaderMaterial: " + identity
		for shader in [material.shader, depth]:
			var error := validate_shader(shader)
			if not error.is_empty(): return "%s: %s" % [identity, error]
		if material.next_pass != null: return "Effect material next_pass is unsupported: " + identity
		definitions[identity] = {"material": material, "depth_shader": depth}
	return ""

func pair(identity: String, color_shader: Shader, depth_shader: Shader) -> Array[ShaderMaterial]:
	var material := ShaderMaterial.new()
	var depth := ShaderMaterial.new()
	if definitions.has(identity):
		material = definitions[identity].material.duplicate() as ShaderMaterial
		depth.shader = definitions[identity].depth_shader
		for uniform in depth.shader.get_shader_uniform_list():
			var value = material.get_shader_parameter(uniform.name)
			if value != null: depth.set_shader_parameter(uniform.name, value)
	else:
		material.shader = color_shader
		depth.shader = depth_shader
	return [material, depth]
