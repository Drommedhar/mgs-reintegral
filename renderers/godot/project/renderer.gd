extends RefCounted

const WorldBlit = preload("res://world_blit.gd")
const DepthCapture = preload("res://depth_capture.gd")
const ScaledVram = preload("res://scaled_vram.gd")

const WIDTH = 1024
const HEIGHT = 512
const SAMPLE_FRAMEBUFFER = 1
const READ_DESTINATION = 8
const HAS_TEXTURE = 16
const PRESERVE_WORLD_COLOR = 32
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
var background_texture: RID
var metadata_texture: RID
var world := WorldBlit.new()
var depth_capture := DepthCapture.new()
var metadata_depth := DepthCapture.new()
var render_scale := 1
var scaled := ScaledVram.new()
var scaled_world := WorldBlit.new()
var world_composites := 0
var native_dirty := Rect2i(0, 0, WIDTH, HEIGHT)
var copied_bytes := 0
var frame_draws := 0
var frame_worlds := 0
var submit_usec := 0
var last_stats := ""

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
	if render_scale > 1:
		var scaled_error := scaled.initialize(rd, texture_format(WIDTH, HEIGHT), shader, snapshot, render_scale)
		if scaled_error.is_empty(): scaled_error = scaled_world.initialize(rd, scaled.framebuffer)
		if not scaled_error.is_empty():
			callback.call_deferred(RID(), scaled_error)
			return
	callback.call_deferred(scaled.target if render_scale > 1 else target, "")

func region(payload: PackedByteArray, offset := 0) -> Rect2i:
	return Rect2i(payload.decode_s32(offset), payload.decode_s32(offset + 4),
		payload.decode_s32(offset + 8), payload.decode_s32(offset + 12))

func valid_region(rect: Rect2i) -> bool:
	return rect.size.x > 0 and rect.size.y > 0 and Rect2i(0, 0, WIDTH, HEIGHT).encloses(rect)

func execute(commands: Array, operation: int, payload: PackedByteArray, callback: Callable) -> void:
	var started := Time.get_ticks_usec()
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
	release_transient()
	submit_usec += Time.get_ticks_usec() - started
	if operation == 7:
		if frame_draws > 0 or frame_worlds > 0:
			last_stats = "DRAW %d  WORLD %d  COPY %.1f MiB  SUBMIT %.2f ms" % [frame_draws, frame_worlds, (copied_bytes + scaled.copied_bytes) / 1048576.0, submit_usec / 1000.0]
		frame_draws = 0
		frame_worlds = 0
		copied_bytes = 0
		scaled.copied_bytes = 0
		submit_usec = 0
	callback.call_deferred(operation, payload, result, error)

func release_transient() -> void:
	transient.reverse()
	for id in transient: rd.free_rid(id)
	transient.clear()

func execute_command(operation: int, payload: PackedByteArray) -> String:
	match operation:
		10:
			world_composites += 1
			frame_worlds += 1
			if payload.size() != 52: return "Invalid world composition payload size: %d" % payload.size()
			if not valid_region(region(payload)) or not region(payload, 32).has_area() or payload.decode_u32(24) >= payload.decode_u32(28) or payload.decode_u32(28) > 65537 or (payload.decode_u32(28) == 65537 and payload.decode_u32(24) != 65536):
				return "Invalid world composition clip=%s view=%s depth=[%d,%d)" % [region(payload), region(payload, 32), payload.decode_u32(24), payload.decode_u32(28)]
			if not depth_capture.error.is_empty(): return depth_capture.error
			if not depth_capture.texture.is_valid(): return "Scene depth is not ready for composition"
			if metadata_texture.is_valid():
				if not metadata_depth.error.is_empty(): return metadata_depth.error
				if not metadata_depth.texture.is_valid(): return "Scene metadata depth is not ready for composition"
			save_native()
			var world_error := world.draw(framebuffer, world_texture, snapshot, depth_capture.texture,
				metadata_texture, metadata_depth.texture, payload, 1, background_texture)
			if world_error.is_empty() and render_scale > 1:
				scaled.save_region(region(payload).intersection(region(payload, 32)))
				world_error = scaled_world.draw(scaled.framebuffer, world_texture, scaled.snapshot, depth_capture.texture,
					metadata_texture, metadata_depth.texture, payload, render_scale, background_texture)
			mark_dirty(region(payload).intersection(region(payload, 32)))
			return world_error
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
			if render_scale > 1: transient.append(scaled.upload(upload, rect))
			mark_dirty(rect)
		4:
			if payload.size() != 24:
				return "Invalid move command"
			var rect := region(payload)
			var destination := Vector2i(payload.decode_s32(16), payload.decode_s32(20))
			if not valid_region(rect) or not valid_region(Rect2i(destination, rect.size)):
				return "Invalid move region"
			save_native()
			if rect.intersects(Rect2i(destination, rect.size)):
				for row in rect.size.y:
					copy(target, snapshot, rect.position + Vector2i(0, row), rect.position, Vector2i(rect.size.x, 1))
					copy(snapshot, target, rect.position, destination + Vector2i(0, row), Vector2i(rect.size.x, 1))
			else:
				copy(target, snapshot, rect.position, rect.position, rect.size)
				copy(snapshot, target, rect.position, destination, rect.size)
			if render_scale > 1: scaled.move(rect, destination)
			mark_dirty(rect)
			mark_dirty(Rect2i(destination, rect.size))
		8:
			if payload.size() != 28:
				return "Invalid clear command"
			var rect := region(payload).intersection(Rect2i(0, 0, WIDTH, HEIGHT))
			if rect.has_area():
				var color := Color(float(payload.decode_u32(16) >> 3) / 31.0, float(payload.decode_u32(20) >> 3) / 31.0, float(payload.decode_u32(24) >> 3) / 31.0, 0)
				rd.draw_list_begin(framebuffer, RenderingDevice.DRAW_CLEAR_COLOR_0, [color], 1.0, 0, Rect2(rect))
				rd.draw_list_end()
				if render_scale > 1: scaled.clear(rect, color)
				mark_dirty(rect)
	return ""

func mark_dirty(rect: Rect2i) -> void:
	if not rect.has_area(): return
	native_dirty = native_dirty.merge(rect) if native_dirty.has_area() else rect
	if render_scale > 1: scaled.mark_dirty(rect)

func save_native() -> void:
	if native_dirty.has_area():
		copy(target, snapshot, native_dirty.position, native_dirty.position, native_dirty.size)
		native_dirty = Rect2i()

func copy(source: RID, destination: RID, start: Vector2i, end: Vector2i, size: Vector2i) -> void:
	copied_bytes += size.x * size.y * 4
	rd.texture_copy(source, destination, Vector3(start.x, start.y, 0),
		Vector3(end.x, end.y, 0), Vector3(size.x, size.y, 1), 0, 0, 0, 0)

func create_slot() -> Dictionary:
	var vertex_buffer := rd.vertex_buffer_create(4096 * 20)
	var index_buffer := rd.index_buffer_create(6144, RenderingDevice.INDEX_BUFFER_FORMAT_UINT16)
	var vertex_uniform := rd.uniform_buffer_create(32)
	var fragment_uniform := rd.uniform_buffer_create(16)
	var scaled_uniform := rd.uniform_buffer_create(16)
	var scaled_vertex := rd.uniform_buffer_create(32)
	return {"vertex": vertex_buffer, "index": index_buffer,
		"vertex_uniform": vertex_uniform, "fragment_uniform": fragment_uniform,
		"vertex_set": rd.uniform_set_create([uniform(0, RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER, [vertex_uniform])], shader, 1),
		"fragment_set": rd.uniform_set_create([uniform(0, RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER, [fragment_uniform])], shader, 3),
		"scaled_uniform": scaled_uniform,
		"scaled_vertex": scaled_vertex,
		"scaled_vertex_set": rd.uniform_set_create([uniform(0, RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER, [scaled_vertex])], shader, 1),
		"scaled_set": rd.uniform_set_create([uniform(0, RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER, [scaled_uniform])], shader, 3),
		"index_array": RID(), "index_count": 0}

func draw(payload: PackedByteArray) -> String:
	if payload.size() < 72:
		return "Truncated draw header"
	var vertices := payload.decode_u32(0)
	var indices := payload.decode_u32(4)
	if vertices < 1 or vertices > 4096 or indices < 1 or indices > 6144 or payload.size() != 72 + vertices * 20 + indices * 2:
		return "Invalid draw size"
	var clip := region(payload, 8)
	if clip.size.x <= 0 or clip.size.y <= 0: return ""
	clip = clip.intersection(Rect2i(0, 0, WIDTH, HEIGHT))
	if not clip.has_area():
		return ""
	if draw_index == slots.size():
		slots.append(create_slot())
	var slot := slots[draw_index]
	draw_index += 1
	frame_draws += 1
	rd.buffer_update(slot.vertex, 0, vertices * 20, payload.slice(72, 72 + vertices * 20))
	rd.buffer_update(slot.index, 0, indices * 2, payload.slice(72 + vertices * 20))
	rd.buffer_update(slot.vertex_uniform, 0, 32, payload.slice(24, 56))
	var fragment := payload.slice(56, 72)
	if world_texture.is_valid(): fragment.encode_u32(12, fragment.decode_u32(12) | PRESERVE_WORLD_COLOR)
	rd.buffer_update(slot.fragment_uniform, 0, 16, fragment)
	if slot.index_count != indices:
		if slot.index_array.is_valid():
			rd.free_rid(slot.index_array)
		slot.index_array = rd.index_array_create(slot.index, 0, indices)
		slot.index_count = indices
	var sampling := payload.decode_u32(68)
	if sampling & (SAMPLE_FRAMEBUFFER | READ_DESTINATION | HAS_TEXTURE) or payload.decode_u32(60) != 0: save_native()
	draw_slot(framebuffer, slot, samplers, slot.vertex_set, slot.fragment_set, clip, vertices)
	if render_scale > 1:
		var vertex := payload.slice(24, 56)
		vertex.encode_float(8, vertex.decode_float(8) / render_scale)
		vertex.encode_float(12, vertex.decode_float(12) / render_scale)
		rd.buffer_update(slot.scaled_vertex, 0, 32, vertex)
		fragment.encode_float(8, float(render_scale))
		fragment.encode_u32(12, fragment.decode_u32(12) | 4)
		rd.buffer_update(slot.scaled_uniform, 0, 16, fragment)
		if sampling & SAMPLE_FRAMEBUFFER:
			scaled.save_dirty()
		elif sampling & READ_DESTINATION or payload.decode_u32(60) != 0:
			scaled.save_region(clip)
		draw_slot(scaled.framebuffer, slot, scaled.samplers, slot.scaled_vertex_set, slot.scaled_set,
			Rect2i(clip.position * render_scale, clip.size * render_scale), vertices)
	mark_dirty(clip)
	return ""

func draw_slot(destination: RID, slot: Dictionary, textures: RID, vertex: RID, fragment: RID, clip: Rect2i, vertices: int) -> void:
	var list := rd.draw_list_begin(destination)
	rd.draw_list_bind_render_pipeline(list, pipeline)
	rd.draw_list_bind_uniform_set(list, vertex, 1)
	rd.draw_list_bind_uniform_set(list, textures, 2)
	rd.draw_list_bind_uniform_set(list, fragment, 3)
	rd.draw_list_bind_vertex_buffers_format(list, vertex_format, vertices, [slot.vertex, slot.vertex, slot.vertex, slot.vertex])
	rd.draw_list_bind_index_array(list, slot.index_array)
	rd.draw_list_enable_scissor(list, Rect2(clip))
	rd.draw_list_draw(list, true, 1)
	rd.draw_list_end()

func read_region(rect: Rect2i) -> PackedByteArray:
	var image := rd.texture_get_data(target, 0)
	var result := PackedByteArray()
	for row in rect.size.y:
		var offset := ((rect.position.y + row) * WIDTH + rect.position.x) * 4
		result.append_array(image.slice(offset, offset + rect.size.x * 4))
	return result

func release(callback: Callable) -> void:
	if rd != null:
		release_transient()
		world.release()
		scaled_world.release()
		scaled.release()
		depth_capture.release()
		metadata_depth.release()
		for slot in slots:
			for key in ["index_array", "vertex_set", "fragment_set", "scaled_set", "scaled_vertex_set", "scaled_vertex", "scaled_uniform", "vertex", "index", "vertex_uniform", "fragment_uniform"]:
				if slot[key].is_valid():
					rd.free_rid(slot[key])
		for id in [pipeline, samplers, framebuffer, sampler, shader, snapshot, target]:
			if id.is_valid():
				rd.free_rid(id)
		slots.clear()
	callback.call_deferred()
