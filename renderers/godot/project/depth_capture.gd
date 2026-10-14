extends CompositorEffect

class OpaqueCoverage extends CompositorEffect:
	var capture: WeakRef

	func _init(target: CompositorEffect) -> void:
		capture = weakref(target)
		effect_callback_type = EFFECT_CALLBACK_TYPE_POST_OPAQUE
		access_resolved_depth = true
		access_resolved_color = true

	func _render_callback(_type: int, data: RenderData) -> void:
		var target = capture.get_ref()
		if target != null: target.record(data, true)

const COMPUTE = """#version 450
layout(local_size_x=8, local_size_y=8) in;
layout(set=0, binding=0) uniform sampler2D scene_depth;
layout(rg32f, set=0, binding=1) uniform image2D output_depth;
layout(set=0, binding=2) uniform sampler2D scene_color;
layout(push_constant, std430) uniform Params { mat4 inverse_projection; uvec4 phase; };
void main() {
    ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = imageSize(output_depth);
    if (any(greaterThanEqual(pixel, size))) return;
    vec2 uv = (vec2(pixel) + 0.5) / vec2(size);
    float depth = texelFetch(scene_depth, pixel, 0).r;
    vec4 view = inverse_projection * vec4(uv * 2.0 - 1.0, depth, 1.0);
    float distance = depth == 0.0 ? 65536.0 : clamp(-1000.0 * view.z / view.w, 0.0, 65535.0);
    vec4 color = texelFetch(scene_color, pixel, 0);
    float coverage = phase.z == 1u ? color.r : color.a;
    // FSR2 uses scene alpha as a reactive mask, so opaque coverage comes from depth.
    if (phase.x == 1u) coverage = depth == 0.0 ? 0.0 : 1.0;
    else if (phase.y == 1u) {
        float opaque = imageLoad(output_depth, pixel).g;
        coverage = opaque + (1.0 - opaque) * coverage;
    }
    imageStore(output_depth, pixel, vec4(distance, clamp(coverage, 0.0, 1.0), 0.0, 0.0));
}
"""

var texture: RID
var shader: RID
var pipeline: RID
var sampler: RID
var size := Vector2i.ZERO
var error := ""
var opaque_pass: CompositorEffect
var capture_heat := false

func _init(preserve_coverage: bool = false, heat_mask: bool = false) -> void:
	capture_heat = heat_mask
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_depth = true
	access_resolved_color = true
	if preserve_coverage: opaque_pass = OpaqueCoverage.new(self)

func effects() -> Array[CompositorEffect]:
	var result: Array[CompositorEffect] = []
	if opaque_pass != null: result.append(opaque_pass)
	result.append(self)
	return result

func initialize(rd: RenderingDevice, extent: Vector2i) -> void:
	var source := RDShaderSource.new()
	source.source_compute = COMPUTE
	var spirv := rd.shader_compile_spirv_from_source(source)
	error = spirv.compile_error_compute
	if not error.is_empty(): return
	shader = rd.shader_create_from_spirv(spirv, "MGS scene depth")
	pipeline = rd.compute_pipeline_create(shader)
	sampler = rd.sampler_create(RDSamplerState.new())
	var format := RDTextureFormat.new()
	format.width = extent.x
	format.height = extent.y
	format.format = RenderingDevice.DATA_FORMAT_R32G32_SFLOAT
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	texture = rd.texture_create(format, RDTextureView.new())
	size = extent

func _render_callback(_type: int, data: RenderData) -> void:
	record(data, false)

func record(data: RenderData, opaque: bool) -> void:
	var buffers := data.get_render_scene_buffers() as RenderSceneBuffersRD
	if buffers == null or not error.is_empty(): return
	var rd := RenderingServer.get_rendering_device()
	var extent := buffers.get_internal_size()
	if extent.x <= 0 or extent.y <= 0: return
	if extent != size:
		release()
		initialize(rd, extent)
	if not error.is_empty(): return
	var depth := RDUniform.new()
	depth.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	depth.binding = 0
	depth.add_id(sampler)
	depth.add_id(buffers.get_depth_layer(0))
	var output := RDUniform.new()
	output.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	output.binding = 1
	output.add_id(texture)
	var color := RDUniform.new()
	color.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	color.binding = 2
	color.add_id(sampler)
	color.add_id(buffers.get_color_layer(0))
	var uniforms := UniformSetCacheRD.get_cache(shader, 0, [depth, output, color])
	var inverse := data.get_render_scene_data().get_cam_projection().inverse()
	var values := PackedFloat32Array()
	for column in [inverse.x, inverse.y, inverse.z, inverse.w]:
		values.append_array([column.x, column.y, column.z, column.w])
	var params := values.to_byte_array()
	params.append_array(PackedInt32Array([int(opaque), int(opaque_pass != null), int(capture_heat), 0]).to_byte_array())
	var list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(list, pipeline)
	rd.compute_list_bind_uniform_set(list, uniforms, 0)
	rd.compute_list_set_push_constant(list, params, 80)
	rd.compute_list_dispatch(list, ceili(extent.x / 8.0), ceili(extent.y / 8.0), 1)
	rd.compute_list_end()

func release() -> void:
	var rd := RenderingServer.get_rendering_device()
	for resource in [texture, pipeline, sampler, shader]:
		if resource.is_valid(): rd.free_rid(resource)
	texture = RID()
	pipeline = RID()
	sampler = RID()
	shader = RID()
	size = Vector2i.ZERO
