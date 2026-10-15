extends SceneTree

const Renderer = preload("res://renderer.gd")
var renderer := Renderer.new()
var failures: Array[String] = []

func _initialize() -> void:
	create_timer(30).timeout.connect(quit.bind(1))
	RenderingServer.call_on_render_thread(renderer.initialize.bind(ready))

func ready(_target: RID, error: String) -> void:
	if not error.is_empty():
		failures.append(error)
		finish()
	else: RenderingServer.call_on_render_thread(check_draws)

func rectangle(water: bool) -> PackedByteArray:
	var data := PackedInt32Array([4,6,0,0,64,64]).to_byte_array()
	data.append_array(PackedFloat32Array([0,0,0,0,1,0,0,0]).to_byte_array())
	data.append_array(PackedInt32Array([0,0]).to_byte_array())
	data.append_array(PackedFloat32Array([1]).to_byte_array())
	data.append_array(PackedInt32Array([64 if water else 0]).to_byte_array())
	for point in [Vector2i(0,0),Vector2i(32,0),Vector2i(0,32),Vector2i(32,32)]:
		var vertex := PackedByteArray()
		vertex.resize(20)
		vertex.encode_s16(0,point.x)
		vertex.encode_s16(2,point.y)
		vertex.encode_u16(10,0x8000)
		vertex[13] = 248
		vertex[15] = 255
		data.append_array(vertex)
	for index in [0,1,2,1,3,2]:
		var item := PackedByteArray([0,0])
		item.encode_u16(0,index)
		data.append_array(item)
	return data

func check_draws() -> void:
	for test in [[false,true,true],[true,true,false],[true,false,true]]:
		renderer.execute_command(8,PackedInt32Array([0,0,64,64,0,0,0]).to_byte_array())
		renderer.suppress_water_effect = test[0]
		var error := renderer.draw(rectangle(test[1]))
		if not error.is_empty(): failures.append(error)
		var pixels := renderer.read_region(Rect2i(10,10,1,1))
		if (pixels[1] > 200) != test[2]: failures.append("Water ownership incorrectly changed tagged draw or ordinary HUD/effect draw: " + str(test))
	finish.call_deferred()

func finish() -> void:
	print("MGS_WATER_EFFECT_TEST failures=%s" % [failures])
	RenderingServer.call_on_render_thread(renderer.release.bind(quit.bind(1 if failures else 0)))
