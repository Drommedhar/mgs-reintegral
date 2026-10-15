extends RefCounted

const PACKET = preload("res://reference_packet.gdshaderinc")
const ORDER = preload("res://reference_order.gdshaderinc")

static func expanded(source: Shader) -> String:
	return source.code.replace('#include "reference_packet.gdshaderinc"', PACKET.code).replace('#include "reference_order.gdshaderinc"', ORDER.code)

static func two_sided(source: Shader) -> Shader:
	var shader := Shader.new()
	shader.code = expanded(source).replace("render_mode ", "render_mode cull_disabled, ")
	return shader

static func transparent(source: Shader) -> Shader:
	var shader := Shader.new()
	var code := expanded(source)
	code = code.replace("render_mode ", "render_mode blend_premul_alpha, depth_draw_never, ")
	code = code.replace("void vertex() {", "uniform sampler2D mask_texture : filter_nearest, repeat_disable;\nvarying flat int blend_mode;\nvoid vertex() {\n    blend_mode = int(texture(packet_texture, UV2).w);")
	code = code.replace("void fragment() {", """void fragment() {
    bool semi = blend_mode != 0 && reference_stp(mask_texture, UV) > 0.5;
    ALPHA = !semi ? 1.0 : (blend_mode == 1 ? 0.5 : 0.0);
    PREMUL_ALPHA_FACTOR = !semi ? 1.0 : (blend_mode == 1 ? 0.5 : (blend_mode == 4 ? 0.25 : 1.0));""")
	shader.code = code
	return shader
