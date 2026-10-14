extends SceneTree

signal gpu_done(target: RID, error: String)
var renderer := preload("res://renderer.gd").new()
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void: run.call_deferred()

func invoke(method: String, arguments: Array = []) -> Array:
	arguments.append(func(target: RID, error: String): gpu_done.emit(target, error))
	RenderingServer.call_on_render_thread(Callable(renderer, method).bindv(arguments))
	return await gpu_done

func upload(value: int) -> void:
	var data := PackedInt32Array([17, 29, 1, 1]).to_byte_array() + PackedByteArray([value, 40, 80, 255])
	check(renderer.execute_command(3, data).is_empty(), "Texture upload failed")

func verify(value: int) -> void:
	var factor: int = renderer.render_scale
	var data: PackedByteArray = renderer.rd.texture_get_data(renderer.display_target(), 0)
	for y in factor:
		for x in factor:
			var offset := ((29*factor+y) * 1024*factor + 17*factor+x)*4
			check(data.slice(offset, offset+4) == PackedByteArray([value,40,80,255]), "Display transition lost current VRAM content")
	check(renderer.read_region(Rect2i(17,29,1,1)) == PackedByteArray([value,40,80,255]), "Display transition changed native VRAM")

func pixels(value: int, write: bool) -> void:
	if write:
		upload(value)
		renderer.present(Rect2i(17, 29, 1, 1))
	verify(value)
	gpu_done.emit.call_deferred(renderer.display_target(), "")

func render_pixels(value: int, write: bool = false) -> void:
	RenderingServer.call_on_render_thread(pixels.bind(value, write))
	await gpu_done

func run() -> void:
	var initialized := await invoke("initialize")
	check(initialized[1].is_empty(), "Renderer initialization failed: " + str(initialized[1]))
	if initialized[1].is_empty():
		await render_pixels(20, true)
		var first: RID = initialized[0]
		check((await invoke("prepare_display", [3]))[1].is_empty(), "Cannot prepare larger target")
		check(renderer.render_scale == 1 and renderer.display_target() == first, "Preparation changed the active target")
		check((await invoke("commit_display"))[1].is_empty(), "Cannot commit larger target")
		check(renderer.render_scale == 3, "Wrong preview scale")
		await render_pixels(20)
		await render_pixels(120, true)
		check((await invoke("finish_display", [true]))[1].is_empty(), "Cannot restore target")
		check(renderer.display_target() == first and renderer.render_scale == 1, "Original target was not retained")
		await render_pixels(120)
		check((await invoke("prepare_display", [2]))[1].is_empty(), "Cannot prepare second change")
		check((await invoke("commit_display"))[1].is_empty(), "Cannot commit second change")
		check((await invoke("finish_display", [false]))[1].is_empty(), "Cannot confirm second change")
		await render_pixels(120)
		var retained: RID = renderer.display_target()
		check((await invoke("prepare_display", [3]))[1].is_empty(), "Cannot prepare third change")
		check((await invoke("commit_display"))[1].is_empty(), "Cannot commit third change")
		await render_pixels(200, true)
		check((await invoke("finish_display", [true]))[1].is_empty(), "Cannot restore scaled target")
		check(renderer.display_target() == retained, "Rollback allocated a new target")
		await render_pixels(200)
		check((await invoke("prepare_display", [9]))[1] != "", "Unsupported scale accepted")
		check((await invoke("prepare_display", [1]))[1].is_empty(), "Cannot prepare native-sized target")
		check((await invoke("discard_display"))[1].is_empty(), "Cannot discard rejected preview")
		check(renderer.display_target() == retained, "Discard changed active target")
		check((await invoke("prepare_display", [1]))[1].is_empty(), "Cannot prepare native-sized preview")
		check((await invoke("commit_display"))[1].is_empty(), "Cannot activate native-sized preview")
		await render_pixels(220, true)
		check((await invoke("finish_display", [true]))[1].is_empty(), "Cannot return from native-sized preview")
		check(renderer.render_scale == 2 and renderer.display_target() == retained, "Scaled target was not retained for native-sized preview")
		await render_pixels(220)
	RenderingServer.call_on_render_thread(renderer.release.bind(done))

func done() -> void:
	print("MGS_DISPLAY_BUFFERS_TEST failures=%d" % failures)
	quit(1 if failures else 0)
