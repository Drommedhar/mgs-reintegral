@tool
extends "night_vision_effect.gd"

@export_group("Heat")
@export var hot_tint := Color(1.0, 0.95, 0.65)
@export_range(0.1, 4.0, 0.01) var heat_curve := 0.7

const THERMAL_COMPUTE = """#version 450
layout(local_size_x=8, local_size_y=8) in;
layout(rgba16f, set=0, binding=0) uniform image2D image;
layout(set=0, binding=1) uniform sampler2D scene_depth;
layout(set=0, binding=2) uniform sampler2D heat_mask;
layout(push_constant, std430) uniform Params {
    vec4 tint_gain; vec4 display; vec4 clock; vec4 hot; mat4 inverse_projection;
};
void main() {
    ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
    ivec2 extent = imageSize(image);
    if (any(greaterThanEqual(pixel, extent))) return;
    vec2 uv = (vec2(pixel) + 0.5) / vec2(extent);
    vec4 color = imageLoad(image, pixel);
    float brightness = pow(max(max(color.r, color.g), max(color.b, 0.0)) + display.x, display.y);
    vec3 cold = tint_gain.rgb * min(brightness * tint_gain.w, 1.0);
    float depth = texelFetch(scene_depth, pixel, 0).r;
    vec4 view = inverse_projection * vec4(uv * 2.0 - 1.0, depth, 1.0);
    float distance = depth == 0.0 ? 65536.0 : -1000.0 * view.z / view.w;
    vec2 mask = textureLod(heat_mask, uv, 0.0).rg;
    float heat = mask.r <= distance + max(5.0, distance * 0.0005) ? mask.g : 0.0;
    vec3 thermal = mix(cold, hot.rgb, pow(clamp(heat, 0.0, 1.0), hot.w));
    float line = 0.5 + 0.5 * cos(uv.y * display.w * 6.2831853);
    vec2 grain_cell = floor(uv * vec2(320.0, 224.0));
    float noise = fract(sin(dot(grain_cell, vec2(12.9898, 78.233)) + clock.x * 0.37) * 43758.5453) - 0.5;
    color.rgb = max(vec3(0.0), thermal * (1.0 - line * display.z) + vec3(noise * clock.y));
    imageStore(image, pixel, color);
}
"""

var sampler: RID
var empty_heat: RID
var heat_capture: CompositorEffect

func _init() -> void:
	super()
	access_resolved_depth = true
	tint = Color(0.5, 0.12, 0.08)
	gain = 0.6
	black_lift = 0.015

func active_mode() -> int:
	return 2

func compute_source() -> String:
	return THERMAL_COMPUTE

func validate() -> String:
	var error := super()
	if not error.is_empty(): return error
	for value in [hot_tint.r, hot_tint.g, hot_tint.b]:
		if not is_finite(value) or value < 0 or value > 1: return "Thermal hot tint must be finite RGB in [0,1]"
	if not is_finite(heat_curve) or heat_curve < 0.1 or heat_curve > 4: return "Thermal heat curve must be in [0.1,4]"
	return ""

func set_heat_capture(capture: CompositorEffect) -> void:
	heat_capture = capture

func pack_parameters(tick: int) -> PackedByteArray:
	var values := super(tick)
	var color := hot_tint.srgb_to_linear()
	values.append_array(PackedFloat32Array([color.r, color.g, color.b, heat_curve]).to_byte_array())
	return values

func push_constants(data: RenderData, values: PackedByteArray) -> PackedByteArray:
	var inverse := data.get_render_scene_data().get_cam_projection().inverse()
	for column in [inverse.x, inverse.y, inverse.z, inverse.w]:
		values.append_array(PackedFloat32Array([column.x, column.y, column.z, column.w]).to_byte_array())
	return values

func prepare() -> void:
	super()
	var rd := RenderingServer.get_rendering_device()
	if rd == null or sampler.is_valid(): return
	sampler = rd.sampler_create(RDSamplerState.new())
	var format := RDTextureFormat.new()
	format.width = 1
	format.height = 1
	format.format = RenderingDevice.DATA_FORMAT_R32G32_SFLOAT
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	empty_heat = rd.texture_create(format, RDTextureView.new(), [PackedFloat32Array([65536, 0]).to_byte_array()])

func extra_bindings(buffers: RenderSceneBuffersRD, view: int) -> Array[RDUniform]:
	var heat: RID = heat_capture.texture if heat_capture != null and heat_capture.texture.is_valid() else empty_heat
	var result: Array[RDUniform] = []
	for texture in [buffers.get_depth_layer(view), heat]:
		var binding := RDUniform.new()
		binding.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		binding.binding = result.size() + 1
		binding.add_id(sampler)
		binding.add_id(texture)
		result.append(binding)
	return result

func release() -> void:
	var rd := RenderingServer.get_rendering_device()
	for resource in [sampler, empty_heat]:
		if resource.is_valid(): rd.free_rid(resource)
	sampler = RID()
	empty_heat = RID()
	super()
