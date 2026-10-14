extends SceneTree

func _initialize() -> void:
	create_timer(90).timeout.connect(quit.bind(1))
	run.call_deferred()

func run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var floor := MeshInstance3D.new()
	floor.mesh = PlaneMesh.new()
	floor.mesh.size = Vector2(20,20)
	floor.mesh.subdivide_width = 100
	floor.mesh.subdivide_depth = 100
	floor.position.y = -4
	scene.add_child(floor)
	var volume: Node3D = load("res://addons/mgs_snow/snow_volume.tscn").instantiate()
	scene.add_child(volume)
	volume.set_physics_process(false)
	var started := Time.get_ticks_usec()
	volume.collision.prepare(10000000)
	volume.collision.sync()
	print("MGS_SNOW_BUILD triangles=20402 ms=%.3f" % ((Time.get_ticks_usec() - started) / 1000.0))
	await physics_frame
	await physics_frame
	for count in [1000,2500,5000]:
		volume.amount = count
		volume.advance(1.0/60)
		var samples: Array[int] = []
		for frame in 120:
			started = Time.get_ticks_usec()
			volume.collision.sync()
			volume.advance(1.0/60)
			samples.append(Time.get_ticks_usec() - started)
			if frame % 30 == 0: await process_frame
		samples.sort()
		print("MGS_SNOW_COST amount=%d median_ms=%.3f p95_ms=%.3f" % [count, samples[60]/1000.0, samples[114]/1000.0])
	scene.free()
	quit()
