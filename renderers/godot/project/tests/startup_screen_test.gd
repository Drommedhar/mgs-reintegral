extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var screen := preload("res://startup_screen.gd").new()
	root.add_child(screen)
	screen.set_process(false)
	check(screen.visible and not screen.animation.visible, "Short startup flashed the animation")
	check(screen.animation.texture.get_size() == Vector2(640, 350), "Loading animation atlas is missing")
	screen._process(0.3)
	check(screen.animation.visible, "Long startup has no animation")
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
	screen.set_loading(false, true, true)
	check(screen.animation.visible, "Animation flashed between native loading and presentation preparation")
	screen.set_loading(false, false, false)
	check(not screen.visible, "Emblem delayed the ready scene")
	screen.free()
	print("MGS_STARTUP_SCREEN_TEST failures=%d" % failures)
	quit(1 if failures else 0)
