extends RefCounted

const SHADER = preload("res://camouflage.gdshader")
const INPUTS = {"camouflage_amount": TYPE_FLOAT, "native_tint": TYPE_VECTOR3}
var template := ShaderMaterial.new()
var resources := preload("res://effect_materials.gd").new()
var source := "default"

func initialize(definitions: Dictionary) -> String:
	template.shader = SHADER
	if not definitions.has("camouflage"): return ""
	var path: String = definitions.camouflage.material
	var error := resources.prepare_textures(path, {})
	if not error.is_empty(): return error
	var material := load(path) as ShaderMaterial
	if material == null or material.shader == null or material.shader.get_mode() != Shader.MODE_SPATIAL:
		return "Camouflage requires a spatial ShaderMaterial"
	if material.next_pass != null: return "Camouflage material next_pass is unsupported"
	var uniforms := {}
	for uniform in material.shader.get_shader_uniform_list(): uniforms[uniform.name] = uniform.type
	for key in INPUTS:
		if uniforms.get(key) != INPUTS[key]:
			return "Camouflage shader is missing native input: " + key
	template = material
	source = definitions.camouflage.get("mod", path)
	return ""

func prepare(entry: Dictionary, key: String) -> void:
	if not entry.has("appearance_cache") or entry.get("appearance_key") == key: return
	for saved in entry.appearance_cache:
		saved.mesh.material_override = saved.override
		for index in saved.surfaces.size(): saved.mesh.set_surface_override_material(index, saved.surfaces[index])
	entry.erase("appearance_cache")
	entry.erase("appearance_shaders")
	entry.erase("appearance_sample")
	entry.material_stages.clear()
	print("MGS_OBJECT_APPEARANCE asset=%s kind=normal" % entry.get("asset", "custom"))

func material_for(source: Material) -> ShaderMaterial:
	var material := template.duplicate() as ShaderMaterial
	var texture: Texture2D
	if source is BaseMaterial3D:
		texture = source.albedo_texture
		material.set_shader_parameter("base_color", source.albedo_color)
	elif source is ShaderMaterial:
		texture = source.get_shader_parameter("albedo_texture") as Texture2D
	material.set_shader_parameter("has_albedo", texture != null)
	material.set_shader_parameter("albedo_texture", texture)
	return material

func apply(entry: Dictionary, key: String, empty_surface: Material) -> void:
	if entry.get("appearance", {}).get("kind", 0) == 0: return
	if not entry.has("appearance_cache"):
		entry.appearance_cache = []
		entry.appearance_shaders = []
		entry.appearance_key = key
		print("MGS_OBJECT_APPEARANCE asset=%s kind=camouflage source=%s" % [entry.get("asset", "custom"), source])
		for mesh in entry.meshes:
			var saved := {"mesh": mesh, "override": mesh.material_override, "surfaces": []}
			for index in mesh.mesh.get_surface_count(): saved.surfaces.append(mesh.get_surface_override_material(index))
			entry.appearance_cache.append(saved)
			if mesh.material_override != null:
				var material := material_for(mesh.material_override)
				mesh.material_override = material
				entry.appearance_shaders.append(material)
			else:
				for index in mesh.mesh.get_surface_count():
					var source: Material = mesh.get_active_material(index)
					if source == empty_surface: continue
					var material := material_for(source)
					mesh.set_surface_override_material(index, material)
					entry.appearance_shaders.append(material)
	if entry.get("appearance_sample") == entry.appearance: return
	entry.appearance_sample = entry.appearance
	for material in entry.appearance_shaders:
		material.set_shader_parameter("camouflage_amount", entry.appearance.amount)
		material.set_shader_parameter("native_tint", entry.appearance.tint)
