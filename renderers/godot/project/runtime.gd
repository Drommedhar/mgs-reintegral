extends Node

const Renderer = preload("res://renderer.gd")
const SceneView = preload("res://scene_view.gd")
const ShaderWarmup = preload("res://shader_warmup.gd")
const DisplaySurface = preload("res://display_surface.gd")
const StartupScreen = preload("res://startup_screen.gd")
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
var session_gate := preload("res://session_gate.gd").new()
var native_context := preload("res://native_context.gd").new()
var retained_palettes := preload("res://retained_palettes.gd").new()
var model_sources := preload("res://model_sources.gd").new()
var native_actors := preload("res://native_actors.gd").new()
var goggles := preload("res://goggles_presenter.gd").new()
var bars := preload("res://bars_presenter.gd").new()
var subtitles := preload("res://subtitles_presenter.gd").new()
var radar := preload("res://radar_presenter.gd").new()
var inventory := preload("res://inventory_presenter.gd").new()
var codec := preload("res://codec_presenter.gd").new()
var options := preload("res://options_presenter.gd").new()
var title := preload("res://title_presenter.gd").new()
var save_load := preload("res://save_presenter.gd").new()
var gpu := Renderer.new()
var screen := TextureRect.new()
var atlas := AtlasTexture.new()
var texture := Texture2DRD.new()
var live_vram := Texture2DRD.new()
var aspect := 4.0 / 3.0
var frame_number := 0
var shutting_down := false
var scene_view := SceneView.new()
var camera_history := preload("res://camera_history.gd").new()
var vision := preload("res://vision_effects.gd").new()
var vision_cut := false
var show_scene := false
var display_enabled := false
var legacy_vram := false
var presentation_region := Rect2(0, 0, 320, 240)
var presentation_aspect := 4.0 / 3.0
var pending_port_switches := 0
var scene_status := Label.new()
var world_viewport := SubViewport.new()
var metadata_viewport := SubViewport.new()
var background_viewport := preload("res://world_background.gd").new()
var thermal_viewport := preload("res://thermal_view.gd").new()
var scene_enabled := false
var scene_dirty := false
var close_requested := false
var stop_request_path := OS.get_environment("MGS_GODOT_STOP_FILE")
var stop_poll_elapsed := 0.0
var debug_panel := PanelContainer.new()
var debug_label := Label.new()
var legacy_debug := preload("res://legacy_debug.gd").new()
var legacy_presentation := preload("res://legacy_presentation.gd").new()
var scene_update_ms := 0.0
var inventory_actions := preload("res://inventory_actions.gd").new()
var codec_actions := preload("res://codec_actions.gd").new()
var title_actions := preload("res://title_actions.gd").new()
var options_actions := preload("res://options_actions.gd").new()
var save_actions := preload("res://save_actions.gd").new()
var settings := preload("res://settings_client.gd").new()
var display_menu := preload("res://display_menu.gd").new()
var display_settings := preload("res://display_settings.gd").new()
var scene_resources := preload("res://scene_resources.gd").new()
var startup_screen: StartupScreen
var preparing_scene := false

func _ready() -> void:
	var startup_phase := Time.get_ticks_msec()
	add_child(settings)
	add_child(inventory_actions)
	scene_view.mod_api.inventory_actions = inventory_actions
	add_child(codec_actions)
	scene_view.mod_api.codec_actions = codec_actions
	add_child(title_actions)
	scene_view.mod_api.title_actions = title_actions
	add_child(options_actions)
	scene_view.mod_api.options_actions = options_actions
	add_child(save_actions)
	scene_view.mod_api.save_actions = save_actions
	add_child(display_settings)
	var display_surface := DisplaySurface.new()
	display_surface.runtime = self
	display_settings.configure(settings, display_surface)
	settings.display = display_settings
	display_settings.changed.connect(func(_state: Dictionary):
		if not settings.snapshot.is_empty(): settings.settings_updated.emit(settings.get_snapshot()))
	settings.request_finished.connect(func(_id: int, error: String):
		if not error.is_empty(): push_warning("Settings: " + error)
		elif _id == 1: print("MGS_SETTINGS_READY " + JSON.stringify({"schema":settings.snapshot.schema,
			"launch":settings.snapshot.launch,"saved":settings.snapshot.saved,"live_apply":settings.snapshot.live_apply})))
	var settings_error := settings.configure(OS.get_environment("MGS_SETTINGS_PORT"), OS.get_environment("MGS_GODOT_SESSION_TOKEN"))
	if not settings_error.is_empty() and not OS.get_environment("MGS_SETTINGS_PORT").is_empty():
		fail(settings_error)
		return
	scene_view.mod_api.settings = settings
	scene_view.add_child(native_actors)
	get_tree().auto_accept_quit = false
	scene_enabled = OS.get_environment("MGS_GODOT_SCENE_VIEW") == "1"
	if scene_enabled:
		startup_screen = StartupScreen.new()
		add_child(startup_screen)
		await get_tree().process_frame
		session_gate.capabilities |= session_gate.DISPLAY | session_gate.INPUT_CAPTURE
		session_gate.capabilities |= session_gate.SCENE_MESHES | session_gate.RETAINED_PALETTES | session_gate.MODEL_SOURCES | session_gate.ELEVATOR_ACTORS | session_gate.DISC_IDENTITY | session_gate.CINEMATIC_CONTEXT | session_gate.INDEPENDENT_VIEW | session_gate.WORLD_SNOW | session_gate.WORLD_SURFACES | session_gate.OBJECT_APPEARANCE | session_gate.VISION_CONTEXT | session_gate.THERMAL_VISION
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
		gpu.render_scale = DisplaySurface.render_factor(extent, OS.get_environment("MGS_GODOT_WIDESCREEN") == "1", scene_enabled)
	world_viewport.size = scene_view.render_extent(maxi(2, gpu.render_scale))
	world_viewport.transparent_bg = true
	world_viewport.own_world_3d = true
	SceneView.configure_rendering(world_viewport, get_viewport())
	world_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(world_viewport)
	world_viewport.add_child(scene_view)
	world_viewport.add_child(thermal_viewport)
	thermal_viewport.initialize(world_viewport)
	SceneView.configure_metadata(metadata_viewport)
	metadata_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(metadata_viewport)
	add_child(background_viewport)
	if scene_enabled:
		var content_error := await scene_view.content.load_responsive(OS.get_environment("MGS_GODOT_ASSETS"), get_tree(), report_loading)
		if shutting_down: return
		if not content_error.is_empty():
			fail(content_error)
			return
		startup_screen.update_phase(1, "Preparing presentation…")
		await get_tree().process_frame
		var scene_error := scene_view.initialize(true)
		print("MGS_STARTUP phase=scene_initialize ms=%d" % (Time.get_ticks_msec() - startup_phase))
		startup_phase = Time.get_ticks_msec()
		if not scene_error.is_empty():
			fail(scene_error)
			return
		scene_view.mod_api.native_actors = native_actors
		var ui_error := goggles.initialize(scene_view.mods.ui, scene_view.asset_root, scene_view.catalog, scene_view.current_disc)
		if not ui_error.is_empty():
			fail(ui_error)
			return
		ui_error = bars.initialize(scene_view.mods.ui, scene_view.asset_root, scene_view.catalog, scene_view.current_disc)
		if not ui_error.is_empty():
			fail(ui_error)
			return
		ui_error = subtitles.initialize(scene_view.mods.ui, scene_view.asset_root, scene_view.catalog, scene_view.current_disc)
		if not ui_error.is_empty():
			fail(ui_error)
			return
		ui_error = radar.initialize(scene_view.mods.ui, scene_view.asset_root, scene_view.catalog, scene_view.current_disc)
		if not ui_error.is_empty():
			fail(ui_error)
			return
		ui_error = inventory.initialize(scene_view.mods.ui, scene_view.asset_root, scene_view.catalog, scene_view.current_disc)
		if not ui_error.is_empty():
			fail(ui_error)
			return
		ui_error = codec.initialize(scene_view.mods.ui, scene_view.asset_root, scene_view.catalog, scene_view.current_disc)
		if not ui_error.is_empty():
			fail(ui_error)
			return
		ui_error = options.initialize(scene_view.mods.ui, scene_view.asset_root, scene_view.catalog, scene_view.current_disc)
		if not ui_error.is_empty():
			fail(ui_error)
			return
		ui_error = title.initialize(scene_view.mods.ui, scene_view.asset_root, scene_view.catalog, scene_view.current_disc)
		if not ui_error.is_empty():
			fail(ui_error)
			return
		ui_error = display_menu.initialize(scene_view.mods.ui, scene_view.asset_root, scene_view.catalog, scene_view.current_disc, settings)
		if not ui_error.is_empty():
			fail(ui_error)
			return
		ui_error = save_load.initialize(scene_view.mods.ui, scene_view.asset_root, scene_view.catalog, scene_view.current_disc)
		if not ui_error.is_empty():
			fail(ui_error)
			return
		if codec.ui.has_method("connect_provider"): codec.ui.connect_provider(codec_actions)
		if inventory.ui.has_method("connect_provider"): inventory.ui.connect_provider(inventory_actions)
		display_menu.ui.capture_changed.connect(inventory_actions.suspend_input)
		display_menu.ui.capture_changed.connect(codec_actions.suspend_input)
		if title.ui.has_method("connect_provider"): title.ui.connect_provider(title_actions)
		display_menu.ui.capture_changed.connect(title_actions.suspend_input)
		if options.ui.has_method("connect_provider"): options.ui.connect_provider(options_actions)
		display_menu.ui.capture_changed.connect(options_actions.suspend_input)
		ui_error = display_menu.register_options(options.ui)
		if not ui_error.is_empty():
			fail(ui_error)
			return
		if save_load.ui.has_method("connect_provider"): save_load.ui.connect_provider(save_actions)
		print("MGS_STARTUP phase=ui_initialize ms=%d" % (Time.get_ticks_msec() - startup_phase))
		startup_phase = Time.get_ticks_msec()
		display_menu.ui.capture_changed.connect(save_actions.suspend_input)
		session_gate.capabilities |= session_gate.INVENTORY_ACTIONS | session_gate.CODEC_ACTIONS | session_gate.TITLE_ACTIONS | session_gate.OPTIONS_ACTIONS | session_gate.SAVE_ACTIONS | session_gate.TITLE | session_gate.SAVE_UI | session_gate.GOGGLES_UI | session_gate.STATUS_BARS | session_gate.SUBTITLES | session_gate.RADAR | session_gate.INVENTORY | session_gate.CODEC | session_gate.OPTIONS
		var vision_error := vision.initialize(scene_view.mods.postprocess, fail)
		if not vision_error.is_empty():
			fail(vision_error)
			return
		var compositor := Compositor.new()
		var world_effects := gpu.depth_capture.effects()
		world_effects.append(vision.world)
		world_effects.append(vision.thermal_world)
		compositor.compositor_effects = world_effects
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
		vision.thermal_world.call("set_heat_capture", thermal_viewport.capture)
		var background_compositor := Compositor.new()
		background_compositor.compositor_effects = [vision.background, vision.thermal_background]
		background_viewport.camera.compositor = background_compositor
		gpu.background_texture = background_viewport.get_texture().get_rid()
		startup_screen.update_phase(2, "Preparing shaders…")
		await ShaderWarmup.prepare(scene_view, get_viewport())
		print("MGS_STARTUP phase=shader_warmup ms=%d" % (Time.get_ticks_msec() - startup_phase))
		startup_screen.update_phase(3, "Starting game…")
	if scene_enabled: gpu.world_texture = world_viewport.get_texture().get_rid()
	var port := int(OS.get_environment("MGS_GODOT_PORT"))
	var token_error := session_gate.configure_token(OS.get_environment("MGS_GODOT_SESSION_TOKEN"))
	if not token_error.is_empty():
		fail(token_error)
		return
	if port < 1024 or port > 65535:
		fail("MGS_GODOT_PORT must be 1024..65535")
		return
	var error := server.listen(port, "127.0.0.1")
	if error != OK:
		fail("Cannot listen on loopback: %s" % error_string(error))
		return
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not scene_enabled and OS.get_environment("MGS_GODOT_WIDESCREEN") == "1":
		screen.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; render_mode unshaded; void fragment() { COLOR = vec4(texture(TEXTURE, UV).rgb, 1.0); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	screen.material = material
	atlas.atlas = texture
	atlas.region = Rect2(0, 0, 320, 240)
	screen.texture = atlas
	add_child(legacy_presentation)
	if not scene_enabled:
		legacy_presentation.initialize(texture, screen.texture_filter)
		screen.texture = legacy_presentation.get_texture()
		screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	screen.visible = false
	add_child(screen)
	add_child(goggles)
	add_child(bars)
	add_child(subtitles)
	add_child(radar)
	add_child(inventory)
	add_child(codec)
	add_child(title)
	add_child(options)
	add_child(save_load)
	add_child(display_menu)
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
	add_child(legacy_debug)
	get_viewport().size_changed.connect(resize_screen)
	resize_screen()
	RenderingServer.call_on_render_thread(gpu.initialize.bind(renderer_ready))

func renderer_ready(target: RID, error: String) -> void:
	if not error.is_empty():
		fail(error)
		return
	texture.texture_rd_rid = target
	if scene_enabled:
		live_vram.texture_rd_rid = gpu.target
		scene_view.materials.live_vram = live_vram
	print("MGS_GODOT_READY protocol=%d.%d renderer=RenderingDevice" % [session_gate.VERSION, session_gate.MINOR])
	print("MGS_RENDER_SIZE scale=%d world=%s output=%s" % [gpu.render_scale, world_viewport.size, get_viewport().get_visible_rect().size])
	print("MGS_WORLD_AA FSR2 scale=%.2f sharpness=%.2f" % [world_viewport.scaling_3d_scale, world_viewport.fsr_sharpness])
	if settings.unavailable_reason.is_empty(): settings.request("read")
	var ready_path := OS.get_environment("MGS_GODOT_READY_FILE")
	if not ready_path.is_empty():
		var ready := FileAccess.open(ready_path, FileAccess.WRITE)
		if ready == null:
			fail("Cannot write renderer readiness file")
			return
		ready.store_string("ready\n")

func resize_screen() -> void:
	var window := Vector2(get_viewport().get_visible_rect().size)
	legacy_debug.fit(Vector2i(window))
	var height := minf(window.y, window.x / aspect)
	screen.size = Vector2(height * aspect, height)
	screen.position = (window - screen.size) * 0.5
	if not scene_enabled:
		var rectangle := DisplaySurface.legacy_rectangle(Vector2i(window), aspect)
		screen.size = rectangle.size
		screen.position = rectangle.position
		legacy_presentation.configure(atlas.region, rectangle.size)
	goggles.fit_screen(Rect2(screen.position, screen.size))
	bars.fit_screen(Rect2(screen.position, screen.size))
	subtitles.fit_screen(Rect2(screen.position, screen.size))
	radar.fit_screen(Rect2(screen.position, screen.size))
	inventory.fit_screen(Rect2(screen.position, screen.size))
	codec.fit_screen(Rect2(screen.position, screen.size))
	title.fit_screen(Rect2(screen.position, screen.size))
	options.fit_screen(Rect2(screen.position, screen.size))
	save_load.fit_screen(Rect2(screen.position, screen.size))
	display_menu.fit_screen(Rect2(screen.position, screen.size))

func fail(message: String) -> void:
	push_error("Godot renderer: " + message)
	shutdown(1)

func report_loading(message: String, percent: float = -1.0) -> void:
	print("MGS_LOAD_PROGRESS " + message + (" (%d%%)" % percent if percent >= 0 else ""))
	if startup_screen != null and startup_screen.phase == 0:
		startup_screen.update_phase(0, message, percent / 100.0 if percent >= 0 else -1.0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_close()

func request_close() -> void:
	close_requested = true
	if peer == null: shutdown(0)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_F2 and session_gate.selected_minor >= 31:
		pending_port_switches += 1
	if not scene_enabled:
		match event.keycode:
			KEY_ESCAPE: request_close()
			KEY_F4:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplaySurface.fullscreen() else DisplayServer.WINDOW_MODE_FULLSCREEN)
			KEY_F6:
				legacy_vram = not legacy_vram
				gpu.present_all_vram = legacy_vram
				update_presentation()
		return
	if event.keycode == KEY_F6:
		show_scene = not show_scene
		screen.texture = world_viewport.get_texture() if show_scene else atlas
	if event.keycode == KEY_F7:
		var error := scene_view.export_snapshot()
		if not error.is_empty(): push_error(error)

func update_presentation() -> void:
	var region := Rect2(0, 0, 1024, 512) if legacy_vram else presentation_region
	atlas.region = Rect2(region.position * gpu.render_scale, region.size * gpu.render_scale)
	aspect = 2.0 if legacy_vram else presentation_aspect
	resize_screen()

func shutdown(exit_code: int) -> void:
	if shutting_down:
		return
	shutting_down = true
	scene_view.content.finish_loading()
	scene_resources.finish_loading()
	set_process(false)
	display_settings.set_process(false)
	goggles.hide()
	bars.hide()
	subtitles.hide()
	radar.hide()
	inventory.hide()
	codec.hide()
	title.hide()
	options.hide()
	save_load.hide()
	display_menu.hide()
	scene_view.mod_api.stop()
	world_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	legacy_presentation.render_target_update_mode = SubViewport.UPDATE_DISABLED
	metadata_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	background_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	thermal_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	thermal_viewport.camera.compositor = null
	scene_view.camera.compositor = null
	scene_view.metadata_camera.compositor = null
	if background_viewport.camera != null: background_viewport.camera.compositor = null
	texture.texture_rd_rid = RID()
	live_vram.texture_rd_rid = RID()
	RenderingServer.call_on_render_thread(vision.release)
	RenderingServer.call_on_render_thread(thermal_viewport.capture.release)
	RenderingServer.call_on_render_thread(gpu.release.bind(get_tree().quit.bind(exit_code)))

func _process(delta: float) -> void:
	if not stop_request_path.is_empty() and not close_requested:
		stop_poll_elapsed += delta
		if stop_poll_elapsed >= 0.25:
			stop_poll_elapsed = 0
			if FileAccess.file_exists(stop_request_path): request_close()
	if shutting_down: return
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
			print("MGS_MODEL_SOURCES declared=%d verified=%d" % [model_sources.models.size(), model_sources.verified_models.size()])
			print("MGS_NATIVE_ACTORS active=%d samples=%d" % [native_actors.actors.size(), native_actors.samples])
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
		var session_error := session_gate.accept(operation, payload)
		if not session_error.is_empty():
			fail(session_error)
			return
		if operation == 1:
			display_settings.session_id = session_gate.public_id.duplicate()
			codec_actions.session_id = session_gate.public_id.duplicate()
			inventory_actions.session_id = session_gate.public_id.duplicate()
			inventory_actions.supported = (session_gate.selected & session_gate.INVENTORY_ACTIONS) != 0
			codec_actions.supported = (session_gate.selected & session_gate.CODEC_ACTIONS) != 0
			title_actions.session_id = session_gate.public_id.duplicate()
			title_actions.supported = (session_gate.selected & session_gate.TITLE_ACTIONS) != 0
			options_actions.session_id = session_gate.public_id.duplicate()
			options_actions.supported = (session_gate.selected & session_gate.OPTIONS_ACTIONS) != 0
			save_actions.session_id = session_gate.public_id.duplicate()
			save_actions.supported = (session_gate.selected & session_gate.SAVE_ACTIONS) != 0
			native_context.session_id = session_gate.public_id.duplicate()
			retained_palettes.session_id = session_gate.public_id.duplicate()
			retained_palettes.deformation_supported = session_gate.selected_minor >= 32
			retained_palettes.live_textures_supported = session_gate.selected_minor >= 33
			model_sources.session_id = session_gate.public_id.duplicate()
			native_actors.session_id = session_gate.public_id.duplicate()
			native_actors.generic_providers = session_gate.selected_minor >= 32
			goggles.state.session_id = session_gate.public_id.duplicate()
			bars.state.session_id = session_gate.public_id.duplicate()
			subtitles.state.session_id = session_gate.public_id.duplicate()
			radar.state.session_id = session_gate.public_id.duplicate()
			inventory.state.session_id = session_gate.public_id.duplicate()
			codec.state.session_id = session_gate.public_id.duplicate()
			title.state.session_id = session_gate.public_id.duplicate()
			options.state.session_id = session_gate.public_id.duplicate()
			save_load.state.session_id = session_gate.public_id.duplicate()
			if session_gate.selected & session_gate.MODEL_SOURCES: scene_view.model_sources = model_sources
			native_context.session_bound = (session_gate.selected & session_gate.SESSION_CONTEXT) != 0
			native_context.disc_identity = (session_gate.selected & session_gate.DISC_IDENTITY) != 0
			native_context.cinematic_context = (session_gate.selected & session_gate.CINEMATIC_CONTEXT) != 0
			native_context.vision_context = (session_gate.selected & session_gate.VISION_CONTEXT) != 0
			vision.thermal_enabled = (session_gate.selected & session_gate.THERMAL_VISION) != 0
			model_sources.disc_identity = native_context.disc_identity
			scene_view.disc_identity = native_context.disc_identity
			scene_view.native_ordering = session_gate.selected_minor >= 35
			native_context.loading_context = native_context.vision_context and session_gate.selected_minor >= 35
			scene_view.object_appearance = (session_gate.selected & session_gate.OBJECT_APPEARANCE) != 0
			if display_menu.ui != null: display_menu.ui.allow_capture((session_gate.selected & session_gate.INPUT_CAPTURE) != 0)
			send_reply(1, session_gate.reply())
		elif operation == 11:
			if payload.size() > 255:
				fail("Invalid debug text length")
				return
			if scene_enabled:
				debug_label.text = payload.get_string_from_utf8()
				if debug_label.text.begins_with("FPS "):
					debug_label.text += "\n" + gpu.last_stats + "\nSCENE CPU %.2f ms" % scene_update_ms
				debug_panel.visible = not payload.is_empty()
			else:
				legacy_debug.set_text(payload.get_string_from_utf8())
		elif operation in [9, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31]:
			if operation in [9, 14] and not scene_enabled:
				continue
			busy = true
			var batch := queued
			queued = []
			queued_bytes = 0
			if batch.is_empty():
				completed(operation, payload, PackedByteArray(), "")
			else:
				submit_commands(batch, operation, payload)
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
	# Native loading can still submit an empty world pass with the previous camera.
	if scene_enabled and not scene_view.world_ready:
		batch = batch.filter(func(command): return command[0] != 10)
	if scene_enabled and scene_dirty and batch.any(func(command): return command[0] == 10):
		scene_dirty = false
		var cut := scene_view.cinematic_camera.consume_history_reset()
		var rig_cut := scene_view.mod_api.presentation_cameras.consume_history_reset()
		cut = cut or rig_cut or vision_cut
		vision_cut = false
		if cut:
			camera_history.begin(scene_view.camera)
			print("MGS_CAMERA_CUT clip=%s source_frame=%d" % [scene_view.cinematic_camera.previous_clip, scene_view.cinematic_context.get("frame", -1)])
		background_viewport.render(scene_view.camera, world_viewport.size)
		var thermal_active := vision.thermal_enabled and vision.mode == 2
		scene_view.effects.set_thermal_active(thermal_active)
		scene_view.thermal_sources.synchronize(scene_view.instances, thermal_active, scene_view.materials.empty_surface, scene_view.camera.cull_mask)
		thermal_viewport.render(scene_view.camera, Vector2i(Vector2(world_viewport.size) * world_viewport.scaling_3d_scale), thermal_active)
		world_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		metadata_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		if cut: camera_history.finish(scene_view.camera)
	if not shutting_down:
		var water_override := scene_enabled and scene_view.world_ready and scene_view.mod_api.owns_underwater_view()
		RenderingServer.call_on_render_thread(gpu.execute.bind(batch, operation, payload, completed, water_override))

func completed(operation: int, payload: PackedByteArray, result: PackedByteArray, error: String) -> void:
	if not error.is_empty():
		fail(error)
		return
	if operation == 26:
		var response := await display_settings.exchange(payload)
		if shutting_down: return
		if response.has("error"):
			fail(response.error)
			return
		send_reply(operation, response.reply)
		busy = false
		parse_commands.call_deferred()
		return
	if operation in [27,28,29,30,31]:
		var provider: Node = {27:save_actions,28:options_actions,29:title_actions,30:codec_actions,31:inventory_actions}[operation]
		var response: Dictionary = provider.exchange_view(payload,native_context.current) if operation>=30 else provider.exchange(payload)
		if response.has("error"):
			fail(response.error)
			return
		send_reply(operation, response.reply)
		busy = false
		parse_commands.call_deferred()
		return
	if operation in [17, 18, 19, 20, 21, 22, 23, 24, 25]:
		var presenter: Control = goggles if operation == 17 else bars if operation == 18 else subtitles if operation == 19 else radar if operation == 20 else inventory if operation == 21 else codec if operation == 22 else options if operation == 23 else save_load if operation == 24 else title
		var ui_error: String = presenter.state.apply(payload, native_context.current)
		if not ui_error.is_empty():
			fail(ui_error)
			return
		busy = false
		parse_commands.call_deferred()
		return
	if operation in [13, 15]:
		var resource_error: String = retained_palettes.apply(payload) if operation == 13 else model_sources.apply(payload)
		if not resource_error.is_empty():
			fail(resource_error)
			return
		busy = false
		parse_commands.call_deferred()
		return
	if operation == 16:
		var actor_error := native_actors.apply(payload, native_context.current)
		if not actor_error.is_empty():
			fail(actor_error)
			return
		scene_view.mod_api.native_actors_updated.emit()
		busy = false
		parse_commands.call_deferred()
		return
	if operation == 12:
		var previous_epoch: int = native_context.current.get("epoch", -1)
		var context_error := native_context.apply(payload)
		if not context_error.is_empty():
			fail(context_error)
			return
		update_loading_screen()
		if scene_enabled and native_context.current.get("loading", false):
			var pending: Array[String] = []
			for definition in scene_view.mods.stage_layers(native_context.current.loading_stage, native_context.current.disc):
				if not definition.path in pending: pending.append(definition.path)
			var prefetch_error := scene_resources.prefetch(pending)
			if not prefetch_error.is_empty():
				fail(prefetch_error)
				return
		if scene_enabled and native_context.disc_identity:
			var disc_error := scene_view.select_disc(native_context.current.disc)
			if not disc_error.is_empty():
				fail(disc_error)
				return
			var ui_error := goggles.select_disc(native_context.current.disc)
			if ui_error.is_empty(): ui_error = bars.select_disc(native_context.current.disc)
			if ui_error.is_empty(): ui_error = subtitles.select_disc(native_context.current.disc)
			if ui_error.is_empty(): ui_error = radar.select_disc(native_context.current.disc)
			if ui_error.is_empty(): ui_error = inventory.select_disc(native_context.current.disc)
			if ui_error.is_empty(): ui_error = codec.select_disc(native_context.current.disc)
			if ui_error.is_empty(): ui_error = title.select_disc(native_context.current.disc)
			if ui_error.is_empty(): ui_error = options.select_disc(native_context.current.disc)
			if ui_error.is_empty(): ui_error = save_load.select_disc(native_context.current.disc)
			if ui_error.is_empty(): ui_error = display_menu.select_disc(native_context.current.disc)
			if not ui_error.is_empty():
				fail(ui_error)
				return
		if previous_epoch != native_context.current.epoch:
			scene_view.world_ready = false
			print("MGS_NATIVE_CONTEXT stage=%s epoch=%d tick=%d disc=%d" % [native_context.current.stage, native_context.current.epoch, native_context.current.actor_loop_tick, native_context.current.disc])
		scene_view.mod_api.publish_native_context(native_context.current)
		if scene_enabled and vision.update(native_context.current):
			vision_cut = true
			scene_dirty = true
		scene_view.cinematic_context = native_context.current.get("cinematic", {})
		busy = false
		parse_commands.call_deferred()
		return
	if operation in [9, 14]:
		if payload.size() >= 68 and scene_view.stage_name(payload, 0) != scene_view.scene_stage:
			preparing_scene = true
			update_loading_screen()
			if SceneView.empty_loading_snapshot(payload) and native_context.current.get("loading", false):
				busy = false
				parse_commands.call_deferred()
				return
			await get_tree().process_frame
			var paths: Array[String] = []
			for definition in scene_view.mods.stage_layers(scene_view.stage_name(payload, 0), scene_view.current_disc):
				if not definition.path in paths: paths.append(definition.path)
			var resource_error := await scene_resources.prepare(paths, get_tree(), report_loading)
			if not resource_error.is_empty():
				fail(resource_error)
				return
			var preparation_error := await scene_view.prepare_stage_responsive(scene_view.stage_name(payload, 0))
			if not preparation_error.is_empty():
				fail(preparation_error)
				return
		var started := Time.get_ticks_usec()
		var previous_clip: String = scene_view.cinematic_camera.active_clip
		var scene_error := scene_view.update_scene(payload, retained_palettes if operation == 14 else null)
		scene_update_ms = (Time.get_ticks_usec() - started) / 1000.0
		if not scene_error.is_empty():
			fail(scene_error)
			return
		preparing_scene = false
		update_loading_screen()
		if previous_clip != scene_view.cinematic_camera.active_clip:
			print("MGS_CAMERA_OWNER clip=%s source_frame=%d" % [scene_view.cinematic_camera.active_clip, scene_view.cinematic_context.get("frame", -1)])
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
		if display_enabled and startup_screen != null: startup_screen.finish()
		update_loading_screen()
		screen.visible = display_enabled
		codec.present(native_context.current.get("epoch", -1), display_enabled)
		codec_actions.present_pending(native_context.current.get("epoch",-1),display_enabled)
		var codec_frame: Dictionary = codec.state.current
		var codec_open: bool = codec_frame.get("mode",0)>0 or (codec_frame.get("active",false) and not codec_frame.get("incoming",false))
		title.present(native_context.current.get("epoch", -1), display_enabled)
		options.present(native_context.current.get("epoch", -1), display_enabled)
		title_actions.present(title.state.current if display_enabled else {})
		options_actions.present(options.state.current if display_enabled else {})
		save_load.present(native_context.current.get("epoch", -1), display_enabled)
		save_actions.present(save_load.state.current if display_enabled else {})
		var hud_enabled: bool = display_enabled and not codec_open and not title.state.current.get("active",false) and not options.state.current.get("active",false) and not save_load.state.current.get("active",false)
		goggles.present(native_context.current.get("epoch", -1), hud_enabled)
		bars.present(native_context.current.get("epoch", -1), hud_enabled)
		subtitles.present(native_context.current.get("epoch", -1), hud_enabled)
		radar.present(native_context.current.get("epoch", -1), hud_enabled)
		inventory.present(native_context.current.get("epoch", -1), hud_enabled)
		inventory_actions.present_pending(native_context.current.get("epoch",-1),hud_enabled)
		inventory.visible = inventory.visible or (hud_enabled and inventory_actions.supported and inventory_actions.get_snapshot().get("active",false))
		presentation_region = Rect2(payload.decode_u32(4), payload.decode_u32(8),
			payload.decode_u32(12), payload.decode_u32(16))
		presentation_aspect = float(payload.decode_u32(20)) / float(payload.decode_u32(24))
		update_presentation()
		frame_number += 1
		if frame_number % 300 == 0:
			print("MGS_RENDER_COST frame=%d %s SCENE CPU %.2f ms" % [frame_number, gpu.last_stats, scene_update_ms])
		if frame_number == int(OS.get_environment("MGS_GODOT_QUIT_FRAME")):
			request_close()
		if preload("res://capture_policy.gd").due(frame_number):
			await capture_presentation(int(OS.get_environment("MGS_GODOT_CAPTURE_EVERY")) > 0)
	send_reply(operation, result)
	busy = false
	parse_commands.call_deferred()

func update_loading_screen() -> void:
	if startup_screen != null:
		var loading: bool = native_context.current.get("loading", false)
		startup_screen.set_loading(loading, preparing_scene, loading or preparing_scene or not display_enabled)

func capture_presentation(sequence: bool = false) -> void:
	if not preload("res://capture_policy.gd").enabled(): return
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
	var buttons := 0
	if DisplayServer.window_is_focused():
		for index in KEYS.size():
			if Input.is_physical_key_pressed(KEYS[index]):
				buttons |= 1 << index
	buttons = display_menu.buttons(buttons, save_actions.captures_input() or options_actions.captures_input() or title_actions.captures_input() or codec_actions.captures_input() or inventory_actions.captures_input())
	if close_requested: buttons |= 0x80000000
	var switch_port := operation != 1 and session_gate.selected_minor >= 31 and pending_port_switches > 0
	if switch_port: buttons |= 0x10000
	var reply := PackedByteArray()
	reply.resize(12)
	reply.encode_u32(0, result.size() + 4)
	reply.encode_u32(4, operation | 0x80000000)
	reply.encode_u32(8, buttons)
	reply.append_array(result)
	if peer.put_data(reply) != OK:
		fail("Socket reply failed")
	elif switch_port:
		pending_port_switches -= 1
