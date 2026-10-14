extends Node3D

var failures := 0
var display: Node
var provider: Node

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func wait_phase(value: String) -> bool:
	var deadline := Time.get_ticks_msec() + 25000
	while display.phase != value and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	check(display.phase == value, "Display phase did not reach " + value + ": " + display.phase + " " + display.last_error)
	return display.phase == value

func _ready() -> void: run.call_deferred()

func preview(values: Dictionary) -> bool:
	var error: String = display.preview(values)
	check(error.is_empty(), "Cannot preview display: " + error)
	if not error.is_empty() or not await wait_phase("preview"): return false
	check(display.applied == values, "Applied display differs from preview")
	await get_tree().process_frame
	await get_tree().process_frame
	var runtime: Node = display.get_parent()
	var extent: Vector2i = runtime.scene_view.render_extent(maxi(2, runtime.gpu.render_scale))
	check(runtime.world_viewport.size == extent and runtime.metadata_viewport.size == extent, "World and metadata dimensions disagree")
	print("MGS_DISPLAY_PREVIEW " + JSON.stringify({"applied":display.applied, "scale":runtime.gpu.render_scale,
		"world":[extent.x,extent.y], "aspect":runtime.aspect, "reference":display._reference,
		"window":[DisplayServer.window_get_size().x,DisplayServer.window_get_size().y]}))
	return true

func run() -> void:
	var api := get_tree().get_first_node_in_group("mgs_visual_api_v1")
	provider = api.get_settings_provider()
	display = provider.display
	var deadline := Time.get_ticks_msec() + 30000
	while (not display.supported or provider.snapshot.is_empty()) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	check(display.supported and not provider.snapshot.is_empty(), "Settings provider did not become ready")
	if not display.supported or provider.snapshot.is_empty():
		done()
		return
	var runtime: Node = display.get_parent()
	while runtime.gpu.world_composites < 10 and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	check(runtime.gpu.world_composites >= 10, "No active Godot world before display changes")
	if runtime.gpu.world_composites < 10:
		done()
		return
	check(provider.get_snapshot().live_apply and provider.get_snapshot().definitions[0].application == "live_confirm", "Runtime settings still advertise restart-only application")
	var original: Dictionary = display.applied.duplicate()
	var wide := {"display.resolution":"1280x720", "display.widescreen":true, "display.fullscreen":false}
	if not await preview(wide):
		done()
		return
	check(display.revert().is_empty(), "Cannot cancel display preview")
	if not await wait_phase("idle"):
		done()
		return
	check(display.applied == original, "Cancelled preview did not restore original")
	if not await preview(wide):
		done()
		return
	if not await wait_phase("idle"):
		done()
		return
	check(display.applied == original and display.last_error.contains("timed out"), "Timed preview did not restore original")
	wide["display.fullscreen"] = true
	if not await preview(wide):
		done()
		return
	check(display.confirm().is_empty(), "Cannot confirm fullscreen preview")
	if not await wait_phase("idle"):
		done()
		return
	check(provider.snapshot.saved == wide and display.applied == wide, "Confirmed display was not saved")
	if not await preview(original):
		done()
		return
	check(display.confirm().is_empty(), "Cannot restore saved original")
	if await wait_phase("idle"):
		check(provider.snapshot.saved == original, "Original profile was not restored")
		check(provider.get_snapshot().applied == original and provider.get_snapshot().unapplied_saved.is_empty(), "Effective settings lost actual applied values")
	done()

func done() -> void:
	print("MGS_DISPLAY_LIVE_TEST failures=%d" % failures)
	if display != null: display.get_parent().request_close()
