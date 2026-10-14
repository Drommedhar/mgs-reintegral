extends SceneTree

var renderer := preload("res://renderer.gd").new()
var failures: Array[String] = []

func _initialize() -> void:
	create_timer(30).timeout.connect(quit.bind(1))
	renderer.render_scale = 4
	renderer.sharp_cards = true
	RenderingServer.call_on_render_thread(renderer.initialize.bind(ready))

func ready(_target: RID, error: String) -> void:
	if not error.is_empty():
		failures.append(error)
		finish()
	else: RenderingServer.call_on_render_thread(run)

func card(sharp: bool) -> PackedByteArray:
	var data := PackedInt32Array([4,6,0,0,32,32]).to_byte_array()
	data.append_array(PackedFloat32Array([0,0,0,0,1,0,0,0]).to_byte_array())
	data.append_array(PackedInt32Array([0,0]).to_byte_array())
	data.append_array(PackedFloat32Array([1]).to_byte_array())
	data.append_array(PackedInt32Array([24 | (128 if sharp else 0)]).to_byte_array())
	for point in [Vector2i(0,0),Vector2i(8,0),Vector2i(0,8),Vector2i(8,8)]:
		var vertex := PackedByteArray()
		vertex.resize(20)
		vertex.encode_s16(0,point.x)
		vertex.encode_s16(2,point.y)
		vertex.encode_u16(4,point.x)
		vertex.encode_u16(6,point.y)
		vertex.encode_u16(10,0x130)
		for index in range(12,15): vertex[index] = 128
		vertex[15] = 128
		vertex[16] = 255
		vertex[17] = 255
		data.append_array(vertex)
	for index in [0,1,2,1,3,2]:
		var item := PackedByteArray([0,0])
		item.encode_u16(0,index)
		data.append_array(item)
	return data

func run() -> void:
	var source := Image.create(8,8,false,Image.FORMAT_RGBA8)
	for y in range(1,7):
		for x in range(1,7):
			if x == y or x == y + 1: source.set_pixel(x,y,Color.WHITE)
	var upload := PackedInt32Array([0,256,8,8]).to_byte_array()
	upload.append_array(source.get_data())
	renderer.execute_command(3,upload)
	var smooth := 0
	var original := PackedByteArray()
	for mode in 3:
		renderer.sharp_cards = mode != 2
		renderer.execute_command(8,PackedInt32Array([0,0,32,32,0,0,0]).to_byte_array())
		var error: String = renderer.draw(card(mode != 0))
		if not error.is_empty(): failures.append(error)
		var pixels := renderer.rd.texture_get_data(renderer.scaled.target,0)
		var intermediate := 0
		var opaque := 0
		for y in 32:
			for x in 32:
				var value: int = pixels[(y * 4096 + x) * 4]
				if value > 8 and value < 247: intermediate += 1
				if value >= 247: opaque += 1
		if opaque == 0: failures.append("Caption fixture did not draw visible text")
		if mode == 0: original = pixels
		elif mode == 1: smooth = intermediate
		elif pixels != original: failures.append("Pixel font option changed original caption pixels")
		if mode != 1 and intermediate != 0: failures.append("Original pixel card changed")
	if smooth < 32: failures.append("Textured caption still has nearest-pixel edges")
	check_edges()
	finish.call_deferred()

func check_edges() -> void:
	var source := Image.create(16,8,false,Image.FORMAT_RGBA8)
	for y in 8:
		for x in range(8,16): source.set_pixel(x,y,Color.WHITE)
	for y in range(2,6): source.set_pixel(y,y,Color.WHITE)
	var upload := PackedInt32Array([0,256,16,8]).to_byte_array()
	upload.append_array(source.get_data())
	renderer.execute_command(3,upload)
	renderer.execute_command(8,PackedInt32Array([0,0,32,32,64,64,64]).to_byte_array())
	renderer.sharp_cards = true
	renderer.draw(card(true))
	var pixels := renderer.rd.texture_get_data(renderer.scaled.target,0)
	var minimum := 255
	for y in 32:
		for x in 32: minimum = mini(minimum, pixels[(y * 4096 + x) * 4])
	if minimum < 64: failures.append("Caption filter turned transparent edges into dark speckles")
	if pixels[31 * 4] > 67: failures.append("Caption filter sampled white neighboring atlas pixels")

func finish() -> void:
	print("MGS_TEXT_CARD_RENDER_TEST failures=", failures)
	RenderingServer.call_on_render_thread(renderer.release.bind(quit.bind(1 if failures else 0)))
