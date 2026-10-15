extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	root.size = Vector2i(1280, 720)
	await process_frame
	var screen := preload("res://startup_screen.gd").new()
	root.add_child(screen)
	screen.set_process(false)
	check(screen.visible and not screen.animation.visible, "Short startup flashed the animation")
	check(screen.animation.texture.get_size() == Vector2(640, 350), "Loading animation atlas is missing")
	screen._process(0.3)
	check(screen.animation.visible, "Long startup has no animation")
	screen.update_phase(0, "Checking disc 1 assets", 0.42)
	check(screen.status.visible and screen.status.text == "Checking disc 1 assets (42%)", "Startup status/progress was discarded")
	check(screen.status.position.x + screen.status.size.x < screen.animation.position.x, "Status overlaps the loading icon")
	screen.update_phase(2, "Preparing shaders…")
	screen.update_phase(0, "Late asset check")
	check(screen.status.text == "Preparing shaders…", "Old progress replaced the current startup phase")
	var frame: int = screen.animation.material.get_shader_parameter("animation_frame")
	screen._process(0.2)
	check(screen.animation.material.get_shader_parameter("animation_frame") != frame, "Animation depends on native ticks")
	screen.elapsed = screen.APPEAR_DELAY + screen.FRAME_COUNT * screen.FRAME_SECONDS
	screen._process(0.0)
	check(screen.animation.material.get_shader_parameter("animation_frame") == 0, "Animation does not loop at original timing")
	screen.finish()
	check(not screen.visible, "Startup emblem remained after readiness")
	screen.set_loading(false, false, true)
	screen._process(1.0)
	check(not screen.visible, "Intentional cinematic black opened loading UI")
	screen.set_loading(true, false, false)
	screen._process(1.0)
	check(not screen.visible, "Loading emblem covered visible gameplay")
	screen.set_loading(true, false, true)
	check(not screen.animation.visible, "Later scene transition skipped the appearance delay")
	screen._process(0.3)
	check(screen.visible and screen.animation.visible, "Native stage load has no animation")
	check(not screen.status.visible, "Startup status leaked into later scene loading")
	screen.set_loading(false, true, true)
	check(screen.animation.visible, "Animation flashed between native loading and presentation preparation")
	screen.set_loading(false, false, false)
	check(not screen.visible, "Emblem delayed the ready scene")
	screen.free()
	print("MGS_STARTUP_SCREEN_TEST failures=%d" % failures)
	quit(1 if failures else 0)
