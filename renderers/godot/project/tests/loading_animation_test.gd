extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var screen := preload("res://startup_screen.gd").new()
	root.add_child(screen)
	screen.set_process(false)
	screen._process(0.3)
	screen.animation.position = Vector2.ZERO
	screen.animation.size = Vector2(160, 140)
	var unique: Dictionary = {}
	var failures := 0
	for frame in screen.FRAME_COUNT:
		screen.animation.material.set_shader_parameter("animation_frame", frame)
		for tick in 2: await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		unique[hash(image.get_data())] = true
		var outline := 0
		for y in 140:
			for x in 160:
				var pixel := image.get_pixel(x, y)
				if pixel.r > 0.5:
					outline += 1
					if not is_equal_approx(pixel.r, pixel.g) or not is_equal_approx(pixel.g, pixel.b): failures += 1
		if outline < 200 or outline > 2500: failures += 1
		if image.get_pixel(80, 60).r > 0.1: failures += 1
		var output := OS.get_environment("MGS_ANIMATION_TEST_IMAGE")
		if frame == 0 and not output.is_empty(): image.save_png(output)
	if unique.size() < 10: failures += 1
	print("MGS_LOADING_ANIMATION_TEST failures=%d unique_frames=%d" % [failures, unique.size()])
	quit(1 if failures else 0)
