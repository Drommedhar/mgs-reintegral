extends RefCounted

const VERTEX = """#version 450
layout(push_constant, std430) uniform Params { vec4 rectangle; vec4 source_region; };
layout(location=0) out vec2 uv;
void main() {
    vec2 corner = vec2((gl_VertexIndex << 1) & 2, gl_VertexIndex & 2);
    uv = source_region.xy + corner * source_region.zw;
    gl_Position = vec4((rectangle.xy + corner * rectangle.zw) / vec2(512.0, 256.0) - 1.0, 0.0, 1.0);
}
"""
const FRAGMENT = """#version 450
layout(set=0, binding=0) uniform sampler2D source;
layout(location=0) in vec2 uv;
layout(location=0) out vec4 color;
void main() { color = texture(source, uv); }
"""

var rd: RenderingDevice
var scale := 1
var target: RID
var presented: RID
var snapshot: RID
var framebuffer: RID
var samplers: RID
var shader: RID
var pipeline: RID
var sampler: RID
var dirty := Rect2i(0, 0, 1024, 512)
var copied_bytes := 0

func initialize(device: RenderingDevice, format: RDTextureFormat, primitive_shader: RID, native_snapshot: RID, factor: int) -> String:
	rd = device
	scale = factor
	format.width *= scale
	format.height *= scale
	target = rd.texture_create(format, RDTextureView.new())
	presented = rd.texture_create(format, RDTextureView.new())
	snapshot = rd.texture_create(format, RDTextureView.new())
	if not target.is_valid() or not snapshot.is_valid() or not presented.is_valid(): return "Cannot allocate scaled display textures"
	rd.texture_clear(target, Color(0, 0, 0, 0), 0, 1, 0, 1)
	rd.texture_clear(presented, Color(0, 0, 0, 0), 0, 1, 0, 1)
	rd.texture_clear(snapshot, Color(0, 0, 0, 0), 0, 1, 0, 1)
	framebuffer = rd.framebuffer_create([target])
	if not framebuffer.is_valid(): return "Cannot allocate scaled display framebuffer"
	var state := RDSamplerState.new()
	state.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	state.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	sampler = rd.sampler_create(state)
	samplers = rd.uniform_set_create([binding(0, native_snapshot), binding(1, snapshot)], primitive_shader, 2)
	var source := RDShaderSource.new()
	source.source_vertex = VERTEX
	source.source_fragment = FRAGMENT
	var spirv := rd.shader_compile_spirv_from_source(source)
	var error := spirv.compile_error_vertex + spirv.compile_error_fragment
	if not error.is_empty(): return error
	shader = rd.shader_create_from_spirv(spirv, "MGS scaled texture upload")
	var blend := RDPipelineColorBlendState.new()
	blend.attachments = [RDPipelineColorBlendStateAttachment.new()]
	pipeline = rd.render_pipeline_create(shader, rd.framebuffer_get_format(framebuffer), -1,
		RenderingDevice.RENDER_PRIMITIVE_TRIANGLES, RDPipelineRasterizationState.new(),
		RDPipelineMultisampleState.new(), RDPipelineDepthStencilState.new(), blend)
	return "" if rd.render_pipeline_is_valid(pipeline) else "Scaled texture upload pipeline creation failed"

func binding(index: int, texture: RID) -> RDUniform:
	var value := RDUniform.new()
	value.binding = index
	value.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	value.add_id(sampler)
	value.add_id(texture)
	return value

func upload(texture: RID, rect: Rect2i) -> RID:
	return _blit(texture, rect, framebuffer, scale, Rect2(0, 0, 1, 1))

func upload_native(texture: RID, rect: Rect2i) -> RID:
	return _blit(texture, rect, framebuffer, scale, _uv_region(rect))

func resolve(destination: RID, rect: Rect2i) -> RID:
	return _blit(target, rect, destination, 1, _uv_region(rect))

func _uv_region(rect: Rect2i) -> Rect2:
	return Rect2(Vector2(rect.position) / Vector2(1024, 512), Vector2(rect.size) / Vector2(1024, 512))

func _blit(texture: RID, rect: Rect2i, destination: RID, factor: int, source_region: Rect2) -> RID:
	var uniforms := rd.uniform_set_create([binding(0, texture)], shader, 0)
	var list := rd.draw_list_begin(destination)
	rd.draw_list_bind_render_pipeline(list, pipeline)
	rd.draw_list_bind_uniform_set(list, uniforms, 0)
	var values := PackedFloat32Array([rect.position.x, rect.position.y, rect.size.x, rect.size.y,
		source_region.position.x, source_region.position.y, source_region.size.x, source_region.size.y]).to_byte_array()
	rd.draw_list_set_push_constant(list, values, 32)
	rd.draw_list_enable_scissor(list, Rect2(rect.position * factor, rect.size * factor))
	rd.draw_list_draw(list, false, 1, 3)
	rd.draw_list_end()
	return uniforms

func copy(source: RID, destination: RID, start: Vector2i, end: Vector2i, size: Vector2i) -> void:
	copied_bytes += size.x * size.y * scale * scale * 4
	rd.texture_copy(source, destination, Vector3(start.x * scale, start.y * scale, 0),
		Vector3(end.x * scale, end.y * scale, 0), Vector3(size.x * scale, size.y * scale, 1), 0, 0, 0, 0)

func save_region(rect: Rect2i) -> void:
	if rect.has_area(): copy(target, snapshot, rect.position, rect.position, rect.size)

func mark_dirty(rect: Rect2i) -> void:
	dirty = dirty.merge(rect) if dirty.has_area() else rect

func save_dirty() -> void:
	if dirty.has_area():
		save_region(dirty)
		dirty = Rect2i()

func move(rect: Rect2i, destination: Vector2i) -> void:
	save_dirty()
	if rect.intersects(Rect2i(destination, rect.size)):
		for row in rect.size.y:
			copy(target, snapshot, rect.position + Vector2i(0, row), rect.position, Vector2i(rect.size.x, 1))
			copy(snapshot, target, rect.position, destination + Vector2i(0, row), Vector2i(rect.size.x, 1))
	else:
		save_region(rect)
		copy(snapshot, target, rect.position, destination, rect.size)

func clear(rect: Rect2i, color: Color) -> void:
	rd.draw_list_begin(framebuffer, RenderingDevice.DRAW_CLEAR_COLOR_0, [color], 1.0, 0,
		Rect2(rect.position * scale, rect.size * scale))
	rd.draw_list_end()

func release() -> void:
	if rd == null: return
	for id in [samplers, framebuffer, pipeline, shader, sampler, snapshot, target, presented]:
		if id.is_valid(): rd.free_rid(id)
