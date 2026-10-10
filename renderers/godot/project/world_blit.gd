extends RefCounted

const VERTEX = """#version 450
layout(push_constant, std430) uniform Params { vec4 rectangle; uint force_mask; uint preserve_mask; uint near_depth; uint far_depth; };
layout(location=0) out vec2 uv;
void main() {
    uv = vec2((gl_VertexIndex << 1) & 2, gl_VertexIndex & 2);
    vec2 pixel = rectangle.xy + uv * rectangle.zw;
    gl_Position = vec4(pixel / vec2(512.0, 256.0) - 1.0, 0.0, 1.0);
}
"""
const FRAGMENT = """#version 450
layout(set=0, binding=0) uniform sampler2D world;
layout(set=0, binding=1) uniform sampler2D destination;
layout(set=0, binding=2) uniform sampler2D scene_depth;
layout(push_constant, std430) uniform Params { vec4 rectangle; uint force_mask; uint preserve_mask; uint near_depth; uint far_depth; };
layout(location=0) in vec2 uv;
layout(location=0) out vec4 color;
void main() {
    ivec2 depth_pixel = clamp(ivec2(uv * textureSize(scene_depth, 0)), ivec2(0), textureSize(scene_depth, 0) - 1);
    float depth = texelFetch(scene_depth, depth_pixel, 0).r;
    if (depth < float(near_depth) || depth >= float(far_depth)) discard;
    vec4 source = texture(world, uv);
    if (source.a < 0.001) discard;
    if (preserve_mask != 0u && texelFetch(destination, ivec2(gl_FragCoord.xy), 0).a > 0.5) discard;
    color = vec4(source.rgb, float(force_mask));
}
"""

var rd: RenderingDevice
var shader: RID
var pipeline: RID
var uniforms: RID
var sampler: RID
var source: RID
var depth_source: RID

func initialize(device: RenderingDevice, framebuffer: RID) -> String:
	rd = device
	var code := RDShaderSource.new()
	code.source_vertex = VERTEX
	code.source_fragment = FRAGMENT
	var spirv := rd.shader_compile_spirv_from_source(code)
	var error := spirv.compile_error_vertex + spirv.compile_error_fragment
	if not error.is_empty():
		return error
	shader = rd.shader_create_from_spirv(spirv, "MGS Godot world composition")
	var blend := RDPipelineColorBlendState.new()
	blend.attachments = [RDPipelineColorBlendStateAttachment.new()]
	pipeline = rd.render_pipeline_create(shader, rd.framebuffer_get_format(framebuffer), -1,
		RenderingDevice.RENDER_PRIMITIVE_TRIANGLES, RDPipelineRasterizationState.new(),
		RDPipelineMultisampleState.new(), RDPipelineDepthStencilState.new(), blend)
	var state := RDSamplerState.new()
	state.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	state.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	sampler = rd.sampler_create(state)
	return "" if rd.render_pipeline_is_valid(pipeline) else "World composition pipeline creation failed"

func draw(framebuffer: RID, texture: RID, snapshot: RID, depth: RID, payload: PackedByteArray) -> String:
	var rectangle := Rect2i(payload.decode_s32(0), payload.decode_s32(4), payload.decode_s32(8), payload.decode_s32(12))
	var viewport := Rect2i(payload.decode_s32(32), payload.decode_s32(36), payload.decode_s32(40), payload.decode_s32(44))
	var current := RenderingServer.texture_get_rd_texture(texture)
	if not current.is_valid():
		return "Godot world viewport has no render texture"
	if current != source or depth != depth_source:
		if uniforms.is_valid():
			rd.free_rid(uniforms)
		source = current
		depth_source = depth
		var binding := RDUniform.new()
		binding.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		binding.binding = 0
		binding.add_id(sampler)
		binding.add_id(source)
		var destination := RDUniform.new()
		destination.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		destination.binding = 1
		destination.add_id(sampler)
		destination.add_id(snapshot)
		var depth_binding := RDUniform.new()
		depth_binding.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		depth_binding.binding = 2
		depth_binding.add_id(sampler)
		depth_binding.add_id(depth)
		uniforms = rd.uniform_set_create([binding, destination, depth_binding], shader, 0)
	var list := rd.draw_list_begin(framebuffer)
	rd.draw_list_bind_render_pipeline(list, pipeline)
	rd.draw_list_bind_uniform_set(list, uniforms, 0)
	var values := PackedFloat32Array([viewport.position.x, viewport.position.y, viewport.size.x, viewport.size.y]).to_byte_array()
	values.append_array(payload.slice(16, 32))
	rd.draw_list_set_push_constant(list, values, 32)
	rd.draw_list_enable_scissor(list, Rect2(rectangle))
	rd.draw_list_draw(list, false, 1, 3)
	rd.draw_list_end()
	return ""

func release() -> void:
	if rd != null:
		for id in [uniforms, pipeline, shader, sampler]:
			if id.is_valid():
				rd.free_rid(id)
