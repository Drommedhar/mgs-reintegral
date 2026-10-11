extends Node

const Renderer = preload("res://renderer.gd")
const SceneView = preload("res://scene_view.gd")
const ShaderWarmup = preload("res://shader_warmup.gd")
const LIMIT = 64 * 1024 * 1024
const KEYS = [KEY_W, KEY_E, KEY_Q, KEY_R, KEY_S, KEY_D, KEY_X, KEY_Z,
	KEY_BACKSPACE, KEY_1, KEY_2, KEY_ENTER, KEY_UP, KEY_RIGHT, KEY_DOWN, KEY_LEFT]

var server := TCPServer.new()
var peer: StreamPeerTCP
var incoming := PackedByteArray()
var queued: Array = []
var queued_bytes := 0
var busy := false
var connected_once := false
var gpu := Renderer.new()
var screen := TextureRect.new()
var atlas := AtlasTexture.new()
var texture := Texture2DRD.new()
var aspect := 4.0 / 3.0
var frame_number := 0
var shutting_down := false
var scene_view := SceneView.new()
var show_scene := false
var display_enabled := false
var scene_status := Label.new()
var world_viewport := SubViewport.new()
var metadata_viewport := SubViewport.new()
var background_viewport := preload("res://world_background.gd").new()
var scene_enabled := false
var scene_dirty := false
var close_requested := false
var debug_panel := PanelContainer.new()
var debug_label := Label.new()
var scene_update_ms := 0.0

func _ready() -> void:
	get_tree().auto_accept_quit = false
	scene_enabled = OS.get_environment("MGS_GODOT_SCENE_VIEW") == "1"
	var requested := OS.get_environment("MGS_GODOT_RENDER_SIZE")
	var dimensions := requested.split("x")
	if not requested.is_empty():
		if dimensions.size() != 2 or not dimensions[0].is_valid_int() or not dimensions[1].is_valid_int():
			fail("Invalid renderer resolution: " + requested)
			return
		var extent := Vector2i(int(dimensions[0]), int(dimensions[1]))
		if extent.x < 320 or extent.y < 240 or extent.x > 2560 or extent.y > 1920:
			fail("Unsupported renderer resolution: " + requested)
			return
		gpu.render_scale = clampi(ceili(minf(extent.x / 320.0, extent.y / 240.0)), 1, 8)
	world_viewport.size = scene_view.render_extent(maxi(2, gpu.render_scale))
	world_viewport.transparent_bg = true
	world_viewport.own_world_3d = true
	SceneView.configure_shadows(world_viewport, get_viewport())
	world_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(world_viewport)
	world_viewport.add_child(scene_view)
	metadata_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(metadata_viewport)
	add_child(background_viewport)
	if scene_enabled:
		var scene_error := scene_view.initialize()
		if not scene_error.is_empty():
			fail(scene_error)
			return
		var compositor := Compositor.new()
		compositor.compositor_effects = [gpu.depth_capture]
		scene_view.camera.compositor = compositor
		metadata_viewport.size = world_viewport.size
		metadata_viewport.transparent_bg = true
		metadata_viewport.world_3d = world_viewport.find_world_3d()
		metadata_viewport.add_child(scene_view.metadata_camera)
		var metadata_compositor := Compositor.new()
		metadata_compositor.compositor_effects = [gpu.metadata_depth]
		scene_view.metadata_camera.compositor = metadata_compositor
		gpu.metadata_texture = metadata_viewport.get_texture().get_rid()
		background_viewport.initialize(world_viewport)
		gpu.background_texture = background_viewport.get_texture().get_rid()
		await ShaderWarmup.prepare(scene_view, get_viewport())
	gpu.world_texture = world_viewport.get_texture().get_rid()
	var port := int(OS.get_environment("MGS_GODOT_PORT"))
	if port < 1024 or port > 65535:
		fail("MGS_GODOT_PORT must be 1024..65535")
		return
	var error := server.listen(port, "127.0.0.1")
	if error != OK:
		fail("Cannot listen on loopback: %s" % error_string(error))
		return
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; render_mode unshaded; void fragment() { COLOR = vec4(texture(TEXTURE, UV).rgb, 1.0); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	screen.material = material
	atlas.atlas = texture
	atlas.region = Rect2(0, 0, 320, 240)
	screen.texture = atlas
	screen.visible = false
	add_child(screen)
	scene_status.position = Vector2(8, 8)
	scene_status.add_theme_color_override("font_color", Color.YELLOW)
	add_child(scene_status)
	debug_panel.position = Vector2(8, 8)
	debug_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_label.add_theme_color_override("font_color", Color.WHITE)
	debug_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	debug_label.add_theme_constant_override("shadow_offset_x", 1)
	debug_label.add_theme_constant_override("shadow_offset_y", 1)
	debug_panel.add_child(debug_label)
	debug_panel.hide()
	add_child(debug_panel)
	get_viewport().size_changed.connect(resize_screen)
	resize_screen()
	RenderingServer.call_on_render_thread(gpu.initialize.bind(renderer_ready))

func renderer_ready(target: RID, error: String) -> void:
	if not error.is_empty():
		fail(error)
		return
	texture.texture_rd_rid = target
	print("MGS_GODOT_READY protocol=13 renderer=RenderingDevice")
	print("MGS_RENDER_SIZE scale=%d world=%s output=%s" % [gpu.render_scale, world_viewport.size, get_viewport().get_visible_rect().size])
	var ready_path := OS.get_environment("MGS_GODOT_READY_FILE")
	if not ready_path.is_empty():
		var ready := FileAccess.open(ready_path, FileAccess.WRITE)
		if ready == null:
			fail("Cannot write renderer readiness file")
			return
		ready.store_string("ready\n")

func resize_screen() -> void:
	var window := Vector2(get_viewport().get_visible_rect().size)
	var height := minf(window.y, window.x / aspect)
	screen.size = Vector2(height * aspect, height)
	screen.position = (window - screen.size) * 0.5

func fail(message: String) -> void:
	push_error("Godot renderer: " + message)
	shutdown(1)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_close()

func request_close() -> void:
	close_requested = true
	if peer == null: shutdown(0)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F6:
		show_scene = not show_scene
		screen.texture = world_viewport.get_texture() if show_scene else atlas
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F7:
		var error := scene_view.export_snapshot()
		if not error.is_empty(): push_error(error)

func shutdown(exit_code: int) -> void:
	if shutting_down:
		return
	shutting_down = true
	set_process(false)
	scene_view.mod_api.stop()
	world_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	metadata_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	background_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	scene_view.camera.compositor = null
	scene_view.metadata_camera.compositor = null
	texture.texture_rd_rid = RID()
	RenderingServer.call_on_render_thread(gpu.release.bind(get_tree().quit.bind(exit_code)))

func _process(_delta: float) -> void:
	if peer == null:
		if server.is_connection_available():
			peer = server.take_connection()
			peer.set_no_delay(true)
			connected_once = true
		return
	peer.poll()
	if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		if connected_once:
			print("MGS native runtime disconnected after %d frames" % frame_number)
			print("MGS_WORLD_COMPOSITES %d" % gpu.world_composites)
			shutdown(0)
		return
	if not receive_commands(): return
	if not busy:
		parse_commands()
	scene_status.text = "Mesh preview · %s · %d instances · F6 game view" % [scene_view.scene_stage, scene_view.current_instances] if show_scene else ""

func receive_commands() -> bool:
	var available := peer.get_available_bytes()
	while available > 0:
		if available > LIMIT - incoming.size():
			fail("Incoming command stream exceeds limit")
			return false
		var received := peer.get_data(available)
		if received[0] != OK:
			fail("Socket receive failed")
			return false
		incoming.append_array(received[1])
		available = peer.get_available_bytes()
	return true

func parse_commands() -> void:
	if shutting_down: return
	var cursor := 0
	while incoming.size() - cursor >= 8 and not busy:
		var length := incoming.decode_u32(cursor)
		var operation := incoming.decode_u32(cursor + 4)
		if length > LIMIT - 8:
			fail("Command exceeds protocol limit")
			return
		if incoming.size() - cursor < length + 8:
			break
		var payload := incoming.slice(cursor + 8, cursor + 8 + length)
		cursor += length + 8
		if operation == 1:
			if payload.size() != 12 or payload.decode_u32(0) != 0x3152474d or payload.decode_u32(4) != 13 or payload.decode_u32(8) != 20:
				fail("Incompatible native renderer protocol")
				return
			send_reply(1, PackedByteArray())
		elif operation == 11:
			if payload.size() > 255:
				fail("Invalid debug text length")
				return
			debug_label.text = payload.get_string_from_utf8()
			if debug_label.text.begins_with("FPS "):
				debug_label.text += "\n" + gpu.last_stats + "\nSCENE CPU %.2f ms" % scene_update_ms
			debug_panel.visible = not payload.is_empty()
		elif operation == 9:
			if not scene_enabled:
				continue
			busy = true
			var batch := queued
			queued = []
			queued_bytes = 0
			if batch.is_empty():
				completed(9, payload, PackedByteArray(), "")
			else:
				submit_commands(batch, 9, payload)
		elif operation in [5, 6, 7]:
			busy = true
			var batch := queued
			queued = []
			queued_bytes = 0
			submit_commands(batch, operation, payload)
		elif operation in [2, 3, 4, 8, 10]:
			queued_bytes += length
			if queued_bytes > LIMIT:
				fail("Unsubmitted render commands exceed limit")
				return
			queued.append([operation, payload])
		else:
			fail("Unknown command %d" % operation)
			return
	if cursor > 0:
		incoming = incoming.slice(cursor)

func submit_commands(batch: Array, operation: int, payload: PackedByteArray) -> void:
	if scene_enabled and scene_dirty and batch.any(func(command): return command[0] == 10):
		scene_dirty = false
		background_viewport.render(scene_view.camera, world_viewport.size)
		world_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		metadata_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
	if not shutting_down:
		RenderingServer.call_on_render_thread(gpu.execute.bind(batch, operation, payload, completed))

func completed(operation: int, payload: PackedByteArray, result: PackedByteArray, error: String) -> void:
	if not error.is_empty():
		fail(error)
		return
	if operation == 9:
		var started := Time.get_ticks_usec()
		var scene_error := scene_view.update_scene(payload)
		scene_update_ms = (Time.get_ticks_usec() - started) / 1000.0
		if not scene_error.is_empty():
			fail(scene_error)
			return
		var extent := scene_view.render_extent(maxi(2, gpu.render_scale))
		if world_viewport.size != extent:
			world_viewport.size = extent
			metadata_viewport.size = extent
		scene_dirty = true
		busy = false
		parse_commands.call_deferred()
		return
	if operation == 7:
		display_enabled = payload.decode_u32(0) != 0
		screen.visible = display_enabled
		atlas.region = Rect2(payload.decode_u32(4), payload.decode_u32(8),
			payload.decode_u32(12), payload.decode_u32(16))
		atlas.region = Rect2(atlas.region.position * gpu.render_scale, atlas.region.size * gpu.render_scale)
		aspect = float(payload.decode_u32(20)) / float(payload.decode_u32(24))
		resize_screen()
		frame_number += 1
		if frame_number % 300 == 0:
			print("MGS_RENDER_COST frame=%d %s SCENE CPU %.2f ms" % [frame_number, gpu.last_stats, scene_update_ms])
		if frame_number == int(OS.get_environment("MGS_GODOT_QUIT_FRAME")):
			request_close()
		var capture_interval := int(OS.get_environment("MGS_GODOT_CAPTURE_EVERY"))
		if frame_number == int(OS.get_environment("MGS_GODOT_CAPTURE_FRAME")) or (capture_interval > 0 and frame_number % capture_interval == 0):
			await capture_presentation(capture_interval > 0)
	send_reply(operation, result)
	busy = false
	parse_commands.call_deferred()

func capture_presentation(sequence: bool = false) -> void:
	await RenderingServer.frame_post_draw
	var path := OS.get_environment("MGS_GODOT_CAPTURE_FILE")
	if path.is_empty():
		fail("Presentation capture frame requires MGS_GODOT_CAPTURE_FILE")
		return
	if sequence:
		path = path.get_basename() + "-%06d.png" % frame_number
	var result := get_viewport().get_texture().get_image().save_png(path)
	if result != OK:
		fail("Cannot save Godot presentation capture: " + error_string(result))
	else:
		print("MGS_GODOT_CAPTURE " + path)
		print("MGS_GODOT_PRESENTATION " + JSON.stringify({"aspect": aspect,
			"screen": [screen.size.x, screen.size.y], "world": [world_viewport.size.x, world_viewport.size.y]}))
		print("MGS_GODOT_PROJECTION " + JSON.stringify(scene_view.projection_diagnostics()))
		print("MGS_WORLD_COMPOSITES %d" % gpu.world_composites)
		if scene_enabled and OS.get_environment("MGS_GODOT_CAPTURE_WORLD") == "1":
			var world_result := world_viewport.get_texture().get_image().save_png(path.get_basename() + "-world.png")
			if world_result != OK: fail("Cannot save world capture: " + error_string(world_result))
		if OS.get_environment("MGS_GODOT_EXPORT_SCENE") == "1":
			var error := scene_view.export_snapshot()
			if not error.is_empty(): fail(error)

func send_reply(operation: int, result: PackedByteArray) -> void:
	var buttons := 0x80000000 if close_requested else 0
	if DisplayServer.window_is_focused():
		for index in KEYS.size():
			if Input.is_physical_key_pressed(KEYS[index]):
				buttons |= 1 << index
	var reply := PackedByteArray()
	reply.resize(12)
	reply.encode_u32(0, result.size() + 4)
	reply.encode_u32(4, operation | 0x80000000)
	reply.encode_u32(8, buttons)
	reply.append_array(result)
	if peer.put_data(reply) != OK:
		fail("Socket reply failed")
