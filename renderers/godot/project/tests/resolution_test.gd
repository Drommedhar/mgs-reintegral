extends SceneTree

const Renderer = preload("res://renderer.gd")
var renderer := Renderer.new()
var viewport := SubViewport.new()
var camera := Camera3D.new()
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	renderer.render_scale = 4
	viewport.size = Vector2i(256, 256)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(camera)
	camera.fov = 90
	var compositor := Compositor.new()
	compositor.compositor_effects = [renderer.depth_capture]
	camera.compositor = compositor
	var quad := MeshInstance3D.new()
	quad.mesh = QuadMesh.new()
	quad.mesh.size = Vector2(4, 4)
	quad.position.z = -2
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = "shader_type spatial; render_mode unshaded; void fragment() { ALBEDO = vec3(UV.x, 0.0, UV.y); }"
	quad.material_override = material
	viewport.add_child(quad)
	renderer.world_texture = viewport.get_texture().get_rid()
	RenderingServer.call_on_render_thread(renderer.initialize.bind(ready))

func ready(target: RID, error: String) -> void:
	if not error.is_empty():
		failures.append(error)
		finish()
		return
	if target != renderer.scaled.target: failures.append("Presentation did not select the scaled framebuffer")
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	RenderingServer.call_on_render_thread(check_render)

func ints(values: Array) -> PackedByteArray:
	return PackedInt32Array(values).to_byte_array()

func pixel(data: PackedByteArray, x: int, y: int) -> PackedByteArray:
	var offset := (y * 4096 + x) * 4
	return data.slice(offset, offset + 4)

func rectangle(preserve: int) -> PackedByteArray:
	var payload := ints([4, 6, 0, 0, 1024, 512])
	payload.append_array(PackedFloat32Array([0, 0, 0, 0, 1, 0, 0, 0]).to_byte_array())
	payload.append_array(ints([0, preserve]))
	payload.append_array(PackedFloat32Array([1]).to_byte_array())
	payload.append_array(ints([0]))
	for position in [Vector2i(20, 20), Vector2i(40, 20), Vector2i(20, 40), Vector2i(40, 40)]:
		var vertex := PackedByteArray()
		vertex.resize(20)
		vertex.encode_s16(0, position.x)
		vertex.encode_s16(2, position.y)
		vertex.encode_u16(10, 0x8000)
		vertex[13] = 248
		vertex[15] = 255
		payload.append_array(vertex)
	for index in [0, 1, 2, 1, 3, 2]:
		var value := PackedByteArray([0, 0])
		value.encode_u16(0, index)
		payload.append_array(value)
	return payload

func command(operation: int, payload: PackedByteArray) -> void:
	var error := renderer.execute_command(operation, payload)
	if not error.is_empty(): failures.append(error)

func tiled_quad(left: int) -> PackedByteArray:
	var payload := rectangle(0)
	payload.encode_float(32, 0.5)
	payload.encode_float(36, 0.5)
	payload.encode_u32(68, 18) # Native texture source and screen-aligned UVs.
	for index in 4:
		var x := left + (16 if index % 2 else 0)
		var y := 16 if index >= 2 else 0
		var offset := 72 + index * 20
		payload.encode_s16(offset, x)
		payload.encode_s16(offset + 2, 80 + y)
		payload.encode_u16(offset + 4, x)
		payload.encode_u16(offset + 6, 128 + y)
		payload.encode_u16(offset + 10, 0x210a)
		for component in 3: payload[offset + 12 + component] = 128
		payload[offset + 16] = 255
		payload[offset + 17] = 255
	return payload

func check_tiles(rd: RenderingDevice) -> void:
	var upload := ints([640, 128, 32, 16])
	for y in 16:
		for x in 32:
			upload.append_array(PackedByteArray([255 if x % 2 else 0, 255, 255 if y % 2 else 0, 255]))
	command(3, upload)
	command(8, ints([0, 80, 32, 16, 248, 0, 0]))
	command(2, tiled_quad(0))
	command(2, tiled_quad(16))
	var image := rd.texture_get_data(renderer.scaled.target, 0)
	var mismatches := 0
	for y in 64:
		for x in 128:
			var expected := PackedByteArray([255 if (x / 4) % 2 else 0, 255, 255 if (y / 4) % 2 else 0, 255])
			if pixel(image, x, 320 + y) != expected: mismatches += 1
	if mismatches: failures.append("Tiled 2D polygons have %d displaced or uncovered samples" % mismatches)
	var native_copies := renderer.copied_bytes
	var scaled_copies := renderer.scaled.copied_bytes
	for index in 10: command(2, rectangle(0))
	if renderer.copied_bytes != native_copies or renderer.scaled.copied_bytes != scaled_copies:
		failures.append("Opaque untextured draws still copy the framebuffer")
	var blend := rectangle(0)
	blend.encode_u32(68, 8)
	for index in 4:
		blend[72 + index * 20 + 13] = 0
		blend[72 + index * 20 + 14] = 248
		blend[72 + index * 20 + 15] = 128
	command(2, blend)
	var blended := rd.texture_get_data(renderer.scaled.target, 0)
	if pixel(blended, 100, 100) != PackedByteArray([0, 128, 128, 0]):
		failures.append("Skipped opaque copies left stale destination pixels for blending")
	var clipped := rectangle(0)
	clipped.encode_s32(16, -1)
	command(2, clipped)

func check_render() -> void:
	var rd := RenderingServer.get_rendering_device()
	command(8, ints([0, 0, 64, 64, 0, 0, 0]))
	command(10, ints([0, 0, 64, 64, 1, 0, 0, 65536, 0, 0, 64, 64, 0]))
	var image := rd.texture_get_data(renderer.scaled.target, 0)
	var detailed := 0
	for y in range(8, 56):
		for x in range(8, 56):
			if pixel(image, x * 4, y * 4) != pixel(image, x * 4 + 3, y * 4 + 3): detailed += 1
	if detailed < 2000: failures.append("High-resolution world lost detail inside native pixel blocks: %d" % detailed)
	check_color_precision(rd, image)
	command(2, rectangle(1))
	var masked := rd.texture_get_data(renderer.scaled.target, 0)
	if pixel(masked, 100, 100) != pixel(image, 100, 100): failures.append("Scaled primitive ignored the world mask")
	command(2, rectangle(0))
	var drawn := rd.texture_get_data(renderer.scaled.target, 0)
	if pixel(drawn, 100, 100) != PackedByteArray([0, 255, 0, 0]): failures.append("Scaled HUD/effect primitive did not cover the world")
	var upload := ints([80, 60, 1, 1]) + PackedByteArray([8, 16, 24, 255])
	command(3, upload)
	command(4, ints([80, 60, 1, 1, 90, 70]))
	var moved := rd.texture_get_data(renderer.scaled.target, 0)
	for y in range(280, 284):
		for x in range(360, 364):
			if pixel(moved, x, y) != PackedByteArray([8, 16, 24, 255]): failures.append("Scaled upload/move lost a texel")
	if renderer.read_region(Rect2i(90, 70, 1, 1)) != PackedByteArray([8, 16, 24, 255]):
		failures.append("Scaled presentation changed native readback dimensions/content")
	print("MGS_RESOLUTION_DETAIL native_blocks_with_subpixel_detail=%d" % detailed)
	check_tiles(rd)
	finish.call_deferred()

func check_color_precision(rd: RenderingDevice, original: PackedByteArray) -> void:
	var native := renderer.read_region(Rect2i(20, 25, 20, 1))
	for mode in 4:
		var effect := rectangle(0)
		effect.encode_u32(68, 8)
		for index in 4:
			var offset := 72 + index * 20
			effect.encode_u16(offset + 10, 0x8000 | (mode << 5))
			effect[offset + 13] = 0
			effect[offset + 15] = 0
		command(2, effect)
		var pixels := rd.texture_get_data(renderer.scaled.target, 0)
		var readback := renderer.read_region(Rect2i(20, 25, 20, 1))
		var factor := 0.5 if mode == 0 else 1.0
		for x in range(80, 160):
			for channel in [0, 2]:
				if absf(pixel(pixels, x, 100)[channel] - pixel(original, x, 100)[channel] * factor) > 1.0:
					failures.append("Effect blend mode %d crushed the Godot gradient" % mode)
		for index in native.size():
			if index % 4 != 3 and absf(readback[index] - native[index] * factor) > 1.0:
				failures.append("Native-size composition lost color precision")
		command(10, ints([0, 0, 64, 64, 1, 0, 0, 65536, 0, 0, 64, 64, 0]))
	var feedback := rectangle(0)
	feedback.encode_u32(68, 17)
	for index in 4:
		var offset := 72 + index * 20
		feedback.encode_s16(offset, 80 + (64 if index % 2 else 0))
		feedback.encode_s16(offset + 2, 64 if index >= 2 else 0)
		feedback.encode_u16(offset + 4, 64 if index % 2 else 0)
		feedback.encode_u16(offset + 6, 64 if index >= 2 else 0)
		feedback.encode_u16(offset + 10, 0x100)
		for channel in 3: feedback[offset + 12 + channel] = 128
		feedback[offset + 16] = 255
		feedback[offset + 17] = 255
	command(2, feedback)
	var copied := rd.texture_get_data(renderer.scaled.target, 0)
	for x in range(8, 248):
		if pixel(copied, x + 320, 100) != pixel(original, x, 100):
			failures.append("Framebuffer feedback rounded the Godot gradient to five bits")

func finish() -> void:
	camera.compositor = null
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	RenderingServer.call_on_render_thread(renderer.release.bind(released))

func released() -> void:
	viewport.free()
	for failure in failures: push_error(failure)
	print("MGS_RESOLUTION_TEST failures=%d" % failures.size())
	quit(0 if failures.is_empty() else 1)
