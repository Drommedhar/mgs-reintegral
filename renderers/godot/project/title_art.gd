@tool
extends "options_art.gd"

@export var use_native_crop := true
static var _shaders: Array[Shader] = []
const CODE = """shader_type canvas_item;
render_mode unshaded, BLENDING;
uniform vec4 source_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 top_tint = vec4(1.0);
uniform vec4 bottom_tint = vec4(1.0);
varying vec4 modulation;
void vertex() {
    modulation = COLOR;
}
void fragment() {
    vec4 tint = mix(top_tint, bottom_tint, UV.y);
    COLOR = modulation * texture(TEXTURE, source_rect.xy + UV * source_rect.zw) * tint;
}
"""

func _init() -> void:
	_layer_count = 8
	if not _shaders.is_empty(): return
	for mode in ["blend_mix", "blend_mix", "blend_add", "blend_sub", "blend_add"]:
		var shader := Shader.new()
		shader.code = CODE.replace("BLENDING", mode)
		_shaders.append(shader)

func apply_material(element: Dictionary) -> void:
	if _authored.material != null or texture == null: return
	var blend: int = element.get("blend", 0)
	var shader_material := material as ShaderMaterial
	if shader_material == null: shader_material = ShaderMaterial.new()
	shader_material.shader = _shaders[blend]
	var region: Rect2 = element.get("source", Rect2(Vector2.ZERO, texture.get_size()))
	var extent := texture.get_size()
	shader_material.set_shader_parameter("source_rect", Vector4(region.position.x/extent.x, region.position.y/extent.y, region.size.x/extent.x, region.size.y/extent.y) if use_native_crop else Vector4(0,0,1,1))
	for side in ["top", "bottom"]:
		var rgb: int = element.get(side+"_rgb", 0x808080) if use_native_color else 0x808080
		var tint := Color((rgb&255)/128.0, ((rgb>>8)&255)/128.0, ((rgb>>16)&255)/128.0, 0.5 if blend == 1 else 1.0)
		if blend == 4: tint *= Color(0.25,0.25,0.25,1)
		shader_material.set_shader_parameter(side+"_tint", tint)
	material = shader_material
