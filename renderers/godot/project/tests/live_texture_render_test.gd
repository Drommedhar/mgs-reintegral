extends SceneTree

var failures := 0
var viewport := SubViewport.new()
var material := ShaderMaterial.new()
var vram := Image.create(1024, 512, false, Image.FORMAT_RGBA8)
var texture: ImageTexture

func check(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)

func word(x: int, y: int, value: int) -> void:
	vram.set_pixel(x, y, Color(float(value & 31) / 31, float((value >> 5) & 31) / 31,
		float((value >> 10) & 31) / 31, float((value >> 15) & 1)))

func _initialize() -> void:
	run.call_deferred()

func frame() -> Image:
	for tick in 3:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func run() -> void:
	viewport.size = Vector2i(64, 32)
	root.add_child(viewport)
	var rect := ColorRect.new()
	rect.size = viewport.size
	viewport.add_child(rect)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\n" + FileAccess.get_file_as_string("res://reference_packet.gdshaderinc") + """
uniform int test_page;
void vertex() {
    vec4 descriptor = live_descriptor(UV);
    live_uv = vec2(UV.x * 4.0, descriptor.y);
    live_page = int(descriptor.z) - 1 + test_page;
    live_clut = int(descriptor.w);
}
void fragment() {
    vec4 pixel = reference_texel(UV);
    COLOR = UV.y < 0.5 ? vec4(pixel.rgb, 1.0) : vec4(pixel.a, reference_stp(albedo_texture, UV), 0.0, 1.0);
}
"""
	material.shader = shader
	rect.material = material
	var colors := [0, 0x1f, 0x03e0, 0x8000]
	for index in colors.size(): word(512 + index, 300, colors[index])
	texture = ImageTexture.create_from_image(vram)
	material.set_shader_parameter("live_vram", texture)
	var descriptor := Image.create_from_data(1, 1, false, Image.FORMAT_RGBAF, PackedFloat32Array([0, 0.5, 1, 19232]).to_byte_array())
	material.set_shader_parameter("live_packet_texture", ImageTexture.create_from_image(descriptor))
	material.set_shader_parameter("has_live_texture", true)
	for depth in 3:
		if depth == 0: word(0, 0, 0x3210)
		elif depth == 1:
			word(0, 0, 0x0100)
			word(1, 0, 0x0302)
		else:
			for index in colors.size(): word(index, 0, colors[index])
		texture.update(vram)
		material.set_shader_parameter("test_page", depth << 7)
		var image := await frame()
		for index in colors.size():
			var expected := Color.RED if index == 1 else (Color.GREEN if index == 2 else Color.BLACK)
			check(image.get_pixel(index * 16 + 8, 8).is_equal_approx(expected), "Live palette color differs at depth%d index%d" % [depth, index])
			var flags := image.get_pixel(index * 16 + 8, 24)
			check(flags.r == (0.0 if index == 0 else 1.0) and flags.g == (1.0 if index == 3 else 0.0), "Transparent-zero or STP differs")
	word(1, 0, 0x7c00)
	texture.update(vram)
	var changed := await frame()
	check(changed.get_pixel(24, 8).is_equal_approx(Color.BLUE), "Live VRAM update stayed cached")
	var authored := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	authored.fill(Color.MAGENTA)
	material.set_shader_parameter("albedo_texture", ImageTexture.create_from_image(authored))
	material.set_shader_parameter("has_live_texture", false)
	var replaced := await frame()
	check(replaced.get_pixel(24, 8).is_equal_approx(Color.MAGENTA), "Non-live material sampled VRAM")
	print("MGS_LIVE_TEXTURE_RENDER_TEST failures=%d" % failures)
	viewport.free()
	quit(1 if failures else 0)
