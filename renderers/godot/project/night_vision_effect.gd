@tool
extends CompositorEffect

signal failed(message: String)

@export_group("Vision")
@export var tint := Color(0.22, 1.0, 0.14)
@export_range(0.0, 32.0, 0.01) var gain := 2.0
@export_range(0.0, 1.0, 0.001) var black_lift := 0.008
@export_range(0.1, 4.0, 0.01) var contrast := 0.8
@export_group("Display")
@export_range(0.0, 1.0, 0.01) var scanline_strength := 0.06
@export_range(1.0, 512.0, 1.0) var scanline_count := 112.0
@export_range(0.0, 0.5, 0.001) var grain_strength := 0.008

const COMPUTE = """#version 450
layout(local_size_x=8, local_size_y=8) in;
layout(rgba16f, set=0, binding=0) uniform image2D image;
layout(push_constant, std430) uniform Params { vec4 tint_gain; vec4 display; vec4 clock; };
void main() {
    ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
    ivec2 extent = imageSize(image);
    if (any(greaterThanEqual(pixel, extent))) return;
    vec4 color = imageLoad(image, pixel);
    float brightness = pow(max(max(color.r, color.g), max(color.b, 0.0)) + display.x, display.y);
    vec2 uv = (vec2(pixel) + 0.5) / vec2(extent);
    float line = 0.5 + 0.5 * cos(uv.y * display.w * 6.2831853);
    vec2 grain_cell = floor(uv * vec2(320.0, 224.0));
    float noise = fract(sin(dot(grain_cell, vec2(12.9898, 78.233)) + clock.x * 0.37) * 43758.5453) - 0.5;
    color.rgb = tint_gain.rgb * max(0.0, brightness * tint_gain.w * (1.0 - line * display.z) + noise * clock.y);
    imageStore(image, pixel, color);
}
"""

var shader: RID
var pipeline: RID
var mutex := Mutex.new()
var parameters := PackedByteArray()

func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_color = true
	enabled = false

func validate() -> String:
	for field in ["gain", "black_lift", "contrast", "scanline_strength", "scanline_count", "grain_strength"]:
		if not is_finite(get(field)): return "Night vision has a nonfinite parameter: " + field
	if gain < 0 or gain > 32 or black_lift < 0 or black_lift > 1 or contrast < 0.1 or contrast > 4:
		return "Night vision gain, lift or contrast is outside its supported range"
	if scanline_strength < 0 or scanline_strength > 1 or scanline_count < 1 or scanline_count > 512 or grain_strength < 0 or grain_strength > 0.5:
		return "Night vision display settings are outside their supported range"
	for channel in [tint.r, tint.g, tint.b]:
		if not is_finite(channel) or channel < 0 or channel > 1: return "Night vision tint must be finite RGB in [0,1]"
	return ""

func set_native_state(mode: int, tick: int) -> void:
	var next := pack_parameters(tick)
	mutex.lock()
	parameters = next
	mutex.unlock()
	enabled = mode == active_mode()

func pack_parameters(tick: int) -> PackedByteArray:
	var linear := tint.srgb_to_linear()
	return PackedFloat32Array([linear.r, linear.g, linear.b, gain,
		black_lift, contrast, scanline_strength, scanline_count,
		float(tick & 65535), grain_strength, 0, 0]).to_byte_array()

func active_mode() -> int:
	return 1

func compute_source() -> String:
	return COMPUTE

func extra_bindings(_buffers: RenderSceneBuffersRD, _view: int) -> Array[RDUniform]:
	return []

func push_constants(_data: RenderData, values: PackedByteArray) -> PackedByteArray:
	return values

func prepare() -> void:
	if pipeline.is_valid(): return
	var rd := RenderingServer.get_rendering_device()
	if rd == null: return
	var source := RDShaderSource.new()
	source.source_compute = compute_source()
	var spirv := rd.shader_compile_spirv_from_source(source)
	if not spirv.compile_error_compute.is_empty():
		failed.emit.call_deferred(spirv.compile_error_compute)
		return
	shader = rd.shader_create_from_spirv(spirv, "MGS night vision")
	pipeline = rd.compute_pipeline_create(shader)
	if not pipeline.is_valid(): failed.emit.call_deferred("Night vision compute pipeline creation failed")

func _render_callback(_type: int, data: RenderData) -> void:
	if not pipeline.is_valid(): return
	var buffers := data.get_render_scene_buffers() as RenderSceneBuffersRD
	if buffers == null: return
	var rd := RenderingServer.get_rendering_device()
	mutex.lock()
	var values := parameters.duplicate()
	mutex.unlock()
	if values.is_empty(): return
	values = push_constants(data, values)
	for view in buffers.get_view_count():
		var binding := RDUniform.new()
		binding.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		binding.binding = 0
		binding.add_id(buffers.get_color_layer(view))
		var bindings: Array[RDUniform] = [binding]
		bindings.append_array(extra_bindings(buffers, view))
		var uniforms := UniformSetCacheRD.get_cache(shader, 0, bindings)
		var extent := buffers.get_internal_size()
		var list := rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(list, pipeline)
		rd.compute_list_bind_uniform_set(list, uniforms, 0)
		rd.compute_list_set_push_constant(list, values, values.size())
		rd.compute_list_dispatch(list, ceili(extent.x / 8.0), ceili(extent.y / 8.0), 1)
		rd.compute_list_end()

func release() -> void:
	var rd := RenderingServer.get_rendering_device()
	for resource in [pipeline, shader]:
		if resource.is_valid(): rd.free_rid(resource)
	pipeline = RID()
	shader = RID()
