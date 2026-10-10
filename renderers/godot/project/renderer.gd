extends RefCounted

const WorldBlit = preload("res://world_blit.gd")
const DepthCapture = preload("res://depth_capture.gd")

const WIDTH = 1024
const HEIGHT = 512
var rd: RenderingDevice
var target: RID
var snapshot: RID
var framebuffer: RID
var shader: RID
var pipeline: RID
var vertex_format: int
var samplers: RID
var sampler: RID
var slots: Array[Dictionary] = []
var transient: Array[RID] = []
var draw_index := 0
var world_texture: RID
var world := WorldBlit.new()
var depth_capture := DepthCapture.new()

func texture_format(width: int, height: int) -> RDTextureFormat:
	var format := RDTextureFormat.new()
	format.width = width
	format.height = height
	format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
	return format

func uniform(binding: int, kind: int, ids: Array[RID]) -> RDUniform:
	var value := RDUniform.new()
	value.binding = binding
	value.uniform_type = kind
	for id in ids:
		value.add_id(id)
	return value

func initialize(callback: Callable) -> void:
	rd = RenderingServer.get_rendering_device()
	if rd == null:
		callback.call_deferred(RID(), "RenderingDevice unavailable; use Forward+ with Vulkan")
		return
	var source := RDShaderSource.new()
	source.source_vertex = FileAccess.get_file_as_string("res://.generated/psx.vert.glsl")
	source.source_fragment = FileAccess.get_file_as_string("res://.generated/psx.frag.glsl")
	var spirv := rd.shader_compile_spirv_from_source(source)
	var errors := spirv.compile_error_vertex + spirv.compile_error_fragment
	if not errors.is_empty():
		callback.call_deferred(RID(), errors)
		return
	shader = rd.shader_create_from_spirv(spirv, "MGS reference primitives")
	target = rd.texture_create(texture_format(WIDTH, HEIGHT), RDTextureView.new())
	snapshot = rd.texture_create(texture_format(WIDTH, HEIGHT), RDTextureView.new())
	rd.texture_clear(target, Color(0, 0, 0, 0), 0, 1, 0, 1)
	rd.texture_clear(snapshot, Color(0, 0, 0, 0), 0, 1, 0, 1)
	framebuffer = rd.framebuffer_create([target])
	var attributes: Array[RDVertexAttribute] = []
	var formats := [RenderingDevice.DATA_FORMAT_R16G16_SINT, RenderingDevice.DATA_FORMAT_R16G16B16A16_UINT, RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM, RenderingDevice.DATA_FORMAT_R8G8B8A8_UINT]
	var offsets := [0, 4, 12, 16]
	for index in 4:
		var attribute := RDVertexAttribute.new()
		attribute.location = index
		attribute.offset = offsets[index]
		attribute.format = formats[index]
		attribute.stride = 20
		attributes.append(attribute)
	vertex_format = rd.vertex_format_create(attributes)
	var blending := RDPipelineColorBlendState.new()
	blending.attachments = [RDPipelineColorBlendStateAttachment.new()]
	pipeline = rd.render_pipeline_create(shader, rd.framebuffer_get_format(framebuffer), vertex_format,
		RenderingDevice.RENDER_PRIMITIVE_TRIANGLES, RDPipelineRasterizationState.new(),
		RDPipelineMultisampleState.new(), RDPipelineDepthStencilState.new(), blending)
	sampler = rd.sampler_create(RDSamplerState.new())
	samplers = rd.uniform_set_create([
		uniform(0, RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE, [sampler, snapshot]),
		uniform(1, RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE, [sampler, snapshot])], shader, 2)
	if not rd.render_pipeline_is_valid(pipeline):
		callback.call_deferred(RID(), "Reference pipeline creation failed")
		return
	var world_error := world.initialize(rd, framebuffer)
	if not world_error.is_empty():
		callback.call_deferred(RID(), world_error)
		return
	callback.call_deferred(target, "")

func region(payload: PackedByteArray, offset := 0) -> Rect2i:
	return Rect2i(payload.decode_s32(offset), payload.decode_s32(offset + 4),
		payload.decode_s32(offset + 8), payload.decode_s32(offset + 12))

func valid_region(rect: Rect2i) -> bool:
	return rect.size.x > 0 and rect.size.y > 0 and Rect2i(0, 0, WIDTH, HEIGHT).encloses(rect)

func execute(commands: Array, operation: int, payload: PackedByteArray, callback: Callable) -> void:
	draw_index = 0
	var error := ""
	for command in commands:
		error = execute_command(command[0], command[1])
		if not error.is_empty():
			break
	var result := PackedByteArray()
	if error.is_empty():
		match operation:
			5:
				if payload.size() != 16 or not valid_region(region(payload)):
					error = "Invalid readback region"
				else:
					result = read_region(region(payload))
			6:
				if not payload.is_empty():
					error = "Invalid sync command"
			7:
				if payload.size() != 28 or not valid_region(region(payload, 4)) or payload.decode_u32(24) == 0:
					error = "Invalid presentation region/aspect"
	for id in transient:
		rd.free_rid(id)
	transient.clear()
	callback.call_deferred(operation, payload, result, error)

func execute_command(operation: int, payload: PackedByteArray) -> String:
	match operation:
		10:
			if payload.size() != 48 or not valid_region(region(payload)) or not region(payload, 32).has_area() or payload.decode_u32(24) >= payload.decode_u32(28) or payload.decode_u32(28) > 65536:
				return "Invalid world composition region"
			if not depth_capture.error.is_empty(): return depth_capture.error
			if not depth_capture.texture.is_valid(): return "Scene depth is not ready for composition"
			copy(target, snapshot, Vector2i.ZERO, Vector2i.ZERO, Vector2i(WIDTH, HEIGHT))
			return world.draw(framebuffer, world_texture, snapshot, depth_capture.texture, payload)
		2:
			return draw(payload)
		3:
			if payload.size() < 16:
				return "Truncated texture upload"
			var rect := region(payload)
			if not valid_region(rect) or payload.size() != 16 + rect.size.x * rect.size.y * 4:
				return "Invalid texture upload"
			var upload := rd.texture_create(texture_format(rect.size.x, rect.size.y), RDTextureView.new(), [payload.slice(16)])
			copy(upload, target, Vector2i.ZERO, rect.position, rect.size)
			transient.append(upload)
		4:
			if payload.size() != 24:
				return "Invalid move command"
			var rect := region(payload)
			var destination := Vector2i(payload.decode_s32(16), payload.decode_s32(20))
			if not valid_region(rect) or not valid_region(Rect2i(destination, rect.size)):
				return "Invalid move region"
			if rect.intersects(Rect2i(destination, rect.size)):
				for row in rect.size.y:
					copy(target, snapshot, rect.position + Vector2i(0, row), rect.position, Vector2i(rect.size.x, 1))
					copy(snapshot, target, rect.position, destination + Vector2i(0, row), Vector2i(rect.size.x, 1))
			else:
				copy(target, snapshot, rect.position, rect.position, rect.size)
				copy(snapshot, target, rect.position, destination, rect.size)
		8:
			if payload.size() != 28:
				return "Invalid clear command"
			var rect := region(payload).intersection(Rect2i(0, 0, WIDTH, HEIGHT))
			if rect.has_area():
				var color := Color(float(payload.decode_u32(16) >> 3) / 31.0, float(payload.decode_u32(20) >> 3) / 31.0, float(payload.decode_u32(24) >> 3) / 31.0, 0)
				rd.draw_list_begin(framebuffer, RenderingDevice.DRAW_CLEAR_COLOR_0, [color], 1.0, 0, Rect2(rect))
				rd.draw_list_end()
	return ""

func copy(source: RID, destination: RID, start: Vector2i, end: Vector2i, size: Vector2i) -> void:
	rd.texture_copy(source, destination, Vector3(start.x, start.y, 0),
		Vector3(end.x, end.y, 0), Vector3(size.x, size.y, 1), 0, 0, 0, 0)

func create_slot() -> Dictionary:
	var vertex_buffer := rd.vertex_buffer_create(4096 * 20)
	var index_buffer := rd.index_buffer_create(6144, RenderingDevice.INDEX_BUFFER_FORMAT_UINT16)
	var vertex_uniform := rd.uniform_buffer_create(32)
	var fragment_uniform := rd.uniform_buffer_create(16)
	return {"vertex": vertex_buffer, "index": index_buffer,
		"vertex_uniform": vertex_uniform, "fragment_uniform": fragment_uniform,
		"vertex_set": rd.uniform_set_create([uniform(0, RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER, [vertex_uniform])], shader, 1),
		"fragment_set": rd.uniform_set_create([uniform(0, RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER, [fragment_uniform])], shader, 3),
		"index_array": RID(), "index_count": 0}

func draw(payload: PackedByteArray) -> String:
	if payload.size() < 72:
		return "Truncated draw header"
	var vertices := payload.decode_u32(0)
	var indices := payload.decode_u32(4)
	if vertices < 1 or vertices > 4096 or indices < 1 or indices > 6144 or payload.size() != 72 + vertices * 20 + indices * 2:
		return "Invalid draw size"
	var clip := region(payload, 8).intersection(Rect2i(0, 0, WIDTH, HEIGHT))
	if not clip.has_area():
		return ""
	if draw_index == slots.size():
		slots.append(create_slot())
	var slot := slots[draw_index]
	draw_index += 1
	rd.buffer_update(slot.vertex, 0, vertices * 20, payload.slice(72, 72 + vertices * 20))
	rd.buffer_update(slot.index, 0, indices * 2, payload.slice(72 + vertices * 20))
	rd.buffer_update(slot.vertex_uniform, 0, 32, payload.slice(24, 56))
	rd.buffer_update(slot.fragment_uniform, 0, 16, payload.slice(56, 72))
	if slot.index_count != indices:
		if slot.index_array.is_valid():
			rd.free_rid(slot.index_array)
		slot.index_array = rd.index_array_create(slot.index, 0, indices)
		slot.index_count = indices
	copy(target, snapshot, Vector2i.ZERO, Vector2i.ZERO, Vector2i(WIDTH, HEIGHT))
	var list := rd.draw_list_begin(framebuffer)
	rd.draw_list_bind_render_pipeline(list, pipeline)
	rd.draw_list_bind_uniform_set(list, slot.vertex_set, 1)
	rd.draw_list_bind_uniform_set(list, samplers, 2)
	rd.draw_list_bind_uniform_set(list, slot.fragment_set, 3)
	rd.draw_list_bind_vertex_buffers_format(list, vertex_format, vertices, [slot.vertex, slot.vertex, slot.vertex, slot.vertex])
	rd.draw_list_bind_index_array(list, slot.index_array)
	rd.draw_list_enable_scissor(list, Rect2(clip))
	rd.draw_list_draw(list, true, 1)
	rd.draw_list_end()
	return ""

func read_region(rect: Rect2i) -> PackedByteArray:
	var image := rd.texture_get_data(target, 0)
	var result := PackedByteArray()
	for row in rect.size.y:
		var offset := ((rect.position.y + row) * WIDTH + rect.position.x) * 4
		result.append_array(image.slice(offset, offset + rect.size.x * 4))
	return result

func release(callback: Callable) -> void:
	if rd != null:
		world.release()
		depth_capture.release()
		for slot in slots:
			for key in ["index_array", "vertex_set", "fragment_set", "vertex", "index", "vertex_uniform", "fragment_uniform"]:
				if slot[key].is_valid():
					rd.free_rid(slot[key])
		for id in [pipeline, samplers, framebuffer, sampler, shader, snapshot, target]:
			if id.is_valid():
				rd.free_rid(id)
		for id in transient:
			rd.free_rid(id)
		slots.clear()
		transient.clear()
	callback.call_deferred()
