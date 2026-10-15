extends Node

const IDLE_PRESENT_USEC := 33333
var active := false
var world_pending := false
var present_pending := false
var last_draw_usec := 0
var last_present_usec := 0

func start() -> void:
	last_draw_usec = Time.get_ticks_usec()
	last_present_usec = last_draw_usec
	active = true
	RenderingServer.render_loop_enabled = false

func stop() -> void:
	active = false
	RenderingServer.render_loop_enabled = true

func _exit_tree() -> void:
	if active: stop()

func _process(_delta: float) -> void:
	if active and not world_pending and Time.get_ticks_usec() - last_present_usec >= IDLE_PRESENT_USEC:
		present()

func world() -> void:
	if not active:
		await RenderingServer.frame_post_draw
		return
	world_pending = true
	# Let SceneTree flush transforms, skeletons and deferred material updates first.
	await get_tree().process_frame
	if active: draw(false)
	world_pending = false

func present() -> void:
	if not active or present_pending: return
	present_pending = true
	flush_presentation.call_deferred()

func flush_presentation() -> void:
	present_pending = false
	if active: draw(true)

func draw(present_window: bool) -> void:
	var now := Time.get_ticks_usec()
	var step := (now - last_draw_usec) / 1000000.0 * Engine.time_scale
	last_draw_usec = now
	if present_window: last_present_usec = now
	RenderingServer.force_draw(present_window, step)
