extends SceneTree

const Runtime = preload("res://runtime.gd")
const Surface = preload("res://display_surface.gd")
var runtime: Node
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func listener() -> TCPServer:
	var server := TCPServer.new()
	for attempt in 100:
		var port := randi_range(1024, 65535)
		if server.listen(port, "127.0.0.1") == OK:
			OS.set_environment("MGS_GODOT_PORT", str(port))
			return server
	failures.append("Cannot reserve a test port")
	return server

func key(code: Key, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.echo = echo
	runtime._unhandled_key_input(event)

func run() -> void:
	await check_initial_presentation()
	for setting in ["MGS_SETTINGS_PORT", "MGS_GODOT_READY_FILE", "MGS_GODOT_STOP_FILE", "MGS_GODOT_CAPTURE_FILE"]:
		OS.set_environment(setting, "")
	OS.set_environment("MGS_GODOT_SCENE_VIEW", "0")
	OS.set_environment("MGS_GODOT_RENDER_SIZE", "1280x720")
	OS.set_environment("MGS_GODOT_WIDESCREEN", "1")
	OS.set_environment("MGS_GODOT_SESSION_TOKEN", "0123456789abcdef0123456789abcdef")
	var reservation := listener()
	reservation.stop()
	runtime = Runtime.new()
	root.add_child(runtime)
	runtime.set_process(false)
	while not runtime.texture.texture_rd_rid.is_valid(): await process_frame
	check(runtime.gpu.render_scale == 4, "Legacy 720p must use native4x scale")
	check(not runtime.gpu.world_texture.is_valid(), "Legacy must keep integer blend precision")
	check(runtime.legacy_presentation.blit.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, "Wide Legacy must use linear presentation")
	for item in [[Vector2i(320,240),false,1], [Vector2i(640,480),false,2], [Vector2i(1280,720),true,4], [Vector2i(2560,1440),true,8]]:
		check(Surface.render_factor(item[0], item[1], false) == item[2], "Legacy scale: " + str(item))
	check(Surface.render_factor(Vector2i(1280,720),true,true) == 3, "Full scene quality scale changed")
	check(Surface.legacy_rectangle(Vector2i(1281,721),4.0/3.0) == Rect2i(160,0,961,721), "Integer pillarbox fitting")
	check(Surface.legacy_rectangle(Vector2i(641,481),10.0/7.0) == Rect2i(0,16,641,449), "Integer original-aspect fitting")
	runtime.presentation_region = Rect2(320,0,320,224)
	runtime.presentation_aspect = 4.0/3.0
	runtime.update_presentation()
	key(KEY_F6)
	check(runtime.gpu.present_all_vram, "F6 must publish the complete VRAM snapshot")
	check(runtime.atlas.region == Rect2(0,0,4096,2048) and runtime.aspect == 2, "F6 must display VRAM")
	key(KEY_F6)
	check(not runtime.gpu.present_all_vram, "Leaving F6 must restore display-region snapshots")
	check(runtime.atlas.region == Rect2(1280,0,1280,896) and runtime.aspect == 4.0/3.0, "F6 must restore presentation")
	key(KEY_F7)
	check(not runtime.show_scene, "Legacy cannot switch to an empty scene")
	runtime.legacy_debug.set_text("FPS 60.0\nCONTROLLER PORT 2\n! AZ az 09 ~")
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(runtime.legacy_debug.texture.atlas.get_image().get_data())
	# Golden RGBA hash from the pinned SDL software renderer's SDL_RenderDebugText.
	check(hash.finish().hex_encode() == "8cf5a297d07dccb94d4468ba3d9996830be7eedf5472d94a90cf3cae92a0932d", "Legacy overlay glyphs/colors changed")
	runtime.legacy_debug.fit(Vector2i(1280,960))
	check(runtime.legacy_debug.position == Vector2(612,12) and runtime.legacy_debug.size == Vector2(656,76), "Legacy overlay fitting")
	runtime.legacy_debug.set_text("")
	check(not runtime.legacy_debug.visible, "Empty native debug text must hide the overlay")
	runtime.session_gate.selected_minor = 30
	key(KEY_F2)
	check(runtime.pending_port_switches == 0, "Old host cannot receive new shortcut bit")
	runtime.session_gate.selected_minor = 31
	key(KEY_F2)
	key(KEY_F2, true)
	key(KEY_F2)
	check(runtime.pending_port_switches == 2, "Distinct F2 presses must survive; repeats must not")
	await check_replies()
	var fullscreen := Surface.fullscreen()
	key(KEY_F4)
	for tick in 3: await process_frame
	check(Surface.fullscreen() != fullscreen, "F4 must toggle fullscreen")
	key(KEY_F4)
	for tick in 3: await process_frame
	check(Surface.fullscreen() == fullscreen, "F4 must restore fullscreen state")
	key(KEY_ESCAPE)
	check(runtime.close_requested, "Escape must request native shutdown")
	print("LEGACY_RUNTIME_TEST failures=", failures.size())
	for failure in failures: push_error(failure)
	runtime.shutdown(0 if failures.is_empty() else 1)

func check_initial_presentation() -> void:
	var presentation := preload("res://legacy_presentation.gd").new()
	root.add_child(presentation)
	var source := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	source.fill(Color.WHITE)
	presentation.initialize(ImageTexture.create_from_image(source), CanvasItem.TEXTURE_FILTER_NEAREST)
	presentation.configure(Rect2(0, 0, 2, 2), presentation.size)
	await RenderingServer.frame_post_draw
	var result := presentation.get_texture().get_image()
	check(result.get_pixel(result.get_width() - 1, result.get_height() - 1) == Color.WHITE,
		"First presentation at default viewport extent must cover the whole image")
	presentation.queue_free()

func check_replies() -> void:
	var server := listener()
	runtime.peer = StreamPeerTCP.new()
	check(runtime.peer.connect_to_host("127.0.0.1", int(OS.get_environment("MGS_GODOT_PORT"))) == OK, "Reply socket connection")
	while not server.is_connection_available(): await process_frame
	var client := server.take_connection()
	runtime.peer.poll()
	for operation in [1, 6, 5, 6]:
		runtime.send_reply(operation, PackedByteArray())
		while client.get_available_bytes() < 12:
			client.poll()
			await process_frame
		var packet: PackedByteArray = client.get_data(12)[1]
		check(bool(packet.decode_u32(8) & 0x10000) == (operation == 5 or (operation == 6 and runtime.pending_port_switches == 1)), "One-shot F2 reply sequencing")
	check(runtime.pending_port_switches == 0, "F2 queue must drain after successful writes")
	server.stop()
