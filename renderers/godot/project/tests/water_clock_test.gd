extends SceneTree

func _initialize() -> void:
	var clock := preload("res://addons/mgs_water/native_clock.gd").new()
	var sample := {"session_id":"a", "epoch":1, "actor_loop_tick":100, "pause_mask":0, "passage_ticks":2}
	clock.update(sample)
	assert(clock.seconds == 0)
	sample.actor_loop_tick += 1
	clock.update(sample)
	assert(is_equal_approx(clock.seconds, 2.0 / clock.TICKS_PER_SECOND))
	clock.update(sample)
	assert(is_equal_approx(clock.seconds, 2.0 / clock.TICKS_PER_SECOND))
	sample.pause_mask = 1
	sample.actor_loop_tick += 1
	clock.update(sample)
	assert(is_equal_approx(clock.seconds, 2.0 / clock.TICKS_PER_SECOND))
	sample.pause_mask = 0
	sample.actor_loop_tick += 1
	clock.update(sample)
	assert(is_equal_approx(clock.seconds, 4.0 / clock.TICKS_PER_SECOND))
	sample.epoch = 2
	clock.update(sample)
	assert(clock.seconds == 0)
	sample.actor_loop_tick += 1
	clock.update(sample)
	assert(clock.seconds > 0)
	sample.session_id = "b"
	clock.update(sample)
	assert(clock.seconds == 0)
	print("MGS_WATER_CLOCK_TEST passed")
	quit()
