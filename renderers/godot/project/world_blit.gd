extends RefCounted

const VERTEX = """#version 450
layout(push_constant, std430) uniform Params { vec4 rectangle; uint force_mask; uint preserve_mask; uint near_depth; uint far_depth; uvec4 options; };
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
layout(set=0, binding=3) uniform sampler2D metadata;
layout(set=0, binding=4) uniform sampler2D metadata_depth;
layout(set=0, binding=5) uniform sampler2D background;
layout(push_constant, std430) uniform Params { vec4 rectangle; uint force_mask; uint preserve_mask; uint near_depth; uint far_depth; uvec4 options; };
layout(location=0) in vec2 uv;
layout(location=0) out vec4 color;
void main() {
    ivec2 depth_pixel = clamp(ivec2(uv * textureSize(scene_depth, 0)), ivec2(0), textureSize(scene_depth, 0) - 1);
    float depth = texelFetch(scene_depth, depth_pixel, 0).r;
    vec4 info = texture(metadata, uv);
    uint flags = 0u;
    if (info.a > 0.5 && abs(texture(metadata_depth, uv).r - depth) < 1.0) {
        uvec3 bytes = uvec3(round(info.rgb * 255.0));
        depth = float(bytes.r + 256u * bytes.g);
        flags = bytes.b;
    }
    bool backdrop = near_depth == 65536u;
    if (!backdrop && (depth < float(near_depth) || depth >= float(far_depth))) discard;
    if (backdrop) flags = 0u;
    vec4 source = backdrop ? texture(background, uv) : texture(world, uv);
    if (source.a < 0.001 && max(max(source.r, source.g), source.b) < 0.001) discard;
    if (preserve_mask != 0u && texelFetch(destination, ivec2(gl_FragCoord.xy), 0).a > 0.5) discard;
    const int dither[16] = int[16](-4, 0, -3, 1, 2, -2, 3, -1, -3, 1, -4, 0, 3, -1, 2, -2);
    ivec2 pixel = ivec2(gl_FragCoord.xy / float(options.y));
    float offset = options.x != 0u ? float(dither[(pixel.y & 3) * 4 + (pixel.x & 3)]) : 0.0;
    vec3 rgb = (flags & 2u) != 0u ? clamp(floor((source.rgb * 255.0 + offset) / 8.0), 0.0, 31.0) / 31.0 : source.rgb;
    rgb += texelFetch(destination, ivec2(gl_FragCoord.xy), 0).rgb * (1.0 - source.a);
    color = vec4(rgb, float(force_mask | (flags & 1u)));
}
"""

var rd: RenderingDevice
var shader: RID
var pipeline: RID
var uniforms: RID
var sampler: RID
var background_sampler: RID
var sources: Array[RID] = []
var empty_metadata: RID

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
	state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	background_sampler = rd.sampler_create(state)
	var format := RDTextureFormat.new()
	format.width = 1
	format.height = 1
	format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	empty_metadata = rd.texture_create(format, RDTextureView.new(), [PackedByteArray([0, 0, 0, 0])])
	return "" if rd.render_pipeline_is_valid(pipeline) else "World composition pipeline creation failed"

func draw(framebuffer: RID, texture: RID, snapshot: RID, depth: RID,
		metadata: RID, metadata_depth: RID, payload: PackedByteArray, scale: int = 1, background: RID = RID()) -> String:
	var rectangle := Rect2i(payload.decode_s32(0), payload.decode_s32(4), payload.decode_s32(8), payload.decode_s32(12))
	var viewport := Rect2i(payload.decode_s32(32), payload.decode_s32(36), payload.decode_s32(40), payload.decode_s32(44))
	var current := RenderingServer.texture_get_rd_texture(texture)
	if not current.is_valid():
		return "Godot world viewport has no render texture"
	var metadata_source := RenderingServer.texture_get_rd_texture(metadata) if metadata.is_valid() else empty_metadata
	var current_sources: Array[RID] = [current, snapshot, depth, metadata_source,
		metadata_depth if metadata.is_valid() else depth,
		RenderingServer.texture_get_rd_texture(background) if background.is_valid() else empty_metadata]
	if current_sources != sources:
		if uniforms.is_valid():
			rd.free_rid(uniforms)
		sources = current_sources
		var bindings: Array[RDUniform] = []
		for index in sources.size():
			var binding := RDUniform.new()
			binding.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
			binding.binding = index
			binding.add_id(background_sampler if index == 5 else sampler)
			binding.add_id(sources[index])
			bindings.append(binding)
		uniforms = rd.uniform_set_create(bindings, shader, 0)
	var list := rd.draw_list_begin(framebuffer)
	rd.draw_list_bind_render_pipeline(list, pipeline)
	rd.draw_list_bind_uniform_set(list, uniforms, 0)
	var values := PackedFloat32Array([viewport.position.x, viewport.position.y, viewport.size.x, viewport.size.y]).to_byte_array()
	values.append_array(payload.slice(16, 32))
	values.append_array(PackedInt32Array([payload.decode_u32(48), scale, 0, 0]).to_byte_array())
	rd.draw_list_set_push_constant(list, values, 48)
	rd.draw_list_enable_scissor(list, Rect2(rectangle.position * scale, rectangle.size * scale))
	rd.draw_list_draw(list, false, 1, 3)
	rd.draw_list_end()
	return ""

func release() -> void:
	if rd != null:
		for id in [uniforms, pipeline, shader, sampler, background_sampler, empty_metadata]:
			if id.is_valid():
				rd.free_rid(id)
