extends SceneTree

const Renderer = preload("res://renderer.gd")
const MATRIX = [-4, 0, -3, 1, 2, -2, 3, -1, -3, 1, -4, 0, 3, -1, 2, -2]
var cases := [["", ""], ["1", "0.5"], ["1", "1.3"], ["1", "1.4"], ["0", "1.3"]]
var renderer: RefCounted
var failures: Array[String] = []
var current: Array
var shade: ImageTexture
var metadata: ImageTexture
var custom_metadata: ImageTexture

func _initialize() -> void:
	call_deferred("run")

func texture(color: Color) -> ImageTexture:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)

func run() -> void:
	shade = texture(Color8(128, 128, 128, 255))
	metadata = texture(Color8(1, 0, 2, 255))
	custom_metadata = texture(Color8(1, 0, 0, 255))
	next_case()

func next_case() -> void:
	if cases.is_empty():
		for failure in failures: push_error(failure)
		if failures.is_empty(): print("PASS: native and WORLD dithering defaults, disable and fractional pattern sizes")
		quit(0 if failures.is_empty() else 1)
		return
	current = cases.pop_front()
	OS.set_environment("MGS_GODOT_DITHERING", current[0])
	OS.set_environment("MGS_GODOT_DITHER_SCALE", current[1])
	renderer = Renderer.new()
	renderer.render_scale = 2
	RenderingServer.call_on_render_thread(renderer.initialize.bind(ready))

func ready(_target: RID, error: String) -> void:
	if not error.is_empty():
		failures.append(error)
		quit(1)
		return
	RenderingServer.call_on_render_thread(check_rendering)

func primitive(dither: bool) -> PackedByteArray:
	var bytes := PackedInt32Array([4, 6, 0, 0, 16, 8]).to_byte_array()
	bytes.append_array(PackedFloat32Array([0, 0, 0, 0, 1, 0, 0, 0]).to_byte_array())
	bytes.append_array(PackedInt32Array([0, 0]).to_byte_array())
	bytes.append_array(PackedFloat32Array([1]).to_byte_array())
	bytes.append_array(PackedInt32Array([0]).to_byte_array())
	for point in [Vector2i(0, 0), Vector2i(16, 0), Vector2i(0, 8), Vector2i(16, 8)]:
		var vertex := PackedByteArray()
		vertex.resize(20)
		vertex.encode_s16(0, point.x)
		vertex.encode_s16(2, point.y)
		vertex.encode_u16(10, 0x8000 | (0x4000 if dither else 0))
		vertex.encode_u32(12, 0xff808080)
		bytes.append_array(vertex)
	for index in [0, 1, 2, 1, 3, 2]:
		var element := PackedByteArray([0, 0])
		element.encode_u16(0, index)
		bytes.append_array(element)
	return bytes

func check_pixels(bytes: PackedByteArray, native_scale: int, active: bool, label: String, custom: bool = false) -> void:
	var scale := 1.0 if str(current[1]).is_empty() else float(current[1])
	for y in 16:
		for x in 32:
			var dx := int((x + 0.5) / (native_scale * scale)) & 3
			var dy := int((y + 0.5) / (native_scale * scale)) & 3
			var offset: int = MATRIX[dy * 4 + dx] if active and current[0] != "0" else 0
			var expected := 128 if custom else (123 if offset < 0 else 132)
			var address := (y * 2048 + x) * 4
			if bytes[address] != expected or bytes[address + 1] != expected or bytes[address + 2] != expected:
				failures.append("%s %s pixel(%d,%d): expected %d, got %s" % [label, current, x, y, expected, bytes.slice(address, address + 4)])
				return

func check_rendering() -> void:
	for active in [true, false]:
		var error: String = renderer.draw(primitive(active))
		if not error.is_empty(): failures.append(error)
		check_pixels(renderer.rd.texture_get_data(renderer.scaled.target, 0), 1, active, "primitive")
	var depth_format := RDTextureFormat.new()
	depth_format.width = 1
	depth_format.height = 1
	depth_format.format = RenderingDevice.DATA_FORMAT_R32G32_SFLOAT
	depth_format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	var depth: RID = renderer.rd.texture_create(depth_format, RDTextureView.new(), [PackedFloat32Array([1, 1]).to_byte_array()])
	for kind in ["enabled", "native-disabled", "custom"]:
		var active: bool = kind != "native-disabled"
		var packet := PackedInt32Array([0, 0, 16, 8, 0, 0, 0, 65536, 0, 0, 16, 8, int(active)]).to_byte_array()
		var info := custom_metadata if kind == "custom" else metadata
		var error: String = renderer.scaled_world.draw(renderer.scaled.framebuffer, shade.get_rid(), renderer.scaled.snapshot,
			depth, info.get_rid(), depth, packet, 2)
		if not error.is_empty(): failures.append(error)
		check_pixels(renderer.rd.texture_get_data(renderer.scaled.target, 0), 2, active, "WORLD " + kind, kind == "custom")
	renderer.rd.free_rid(depth)
	renderer.release(next_case)
