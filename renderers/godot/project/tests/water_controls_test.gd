extends SceneTree

var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Water controls test needs a rendering device to read shader defaults")
		quit(1)
		return
	var pool: Node3D = load("res://addons/mgs_water/pool.tscn").instantiate()
	var ocean: Node3D = load("res://addons/mgs_water/ocean.tscn").instantiate()
	root.add_child(pool)
	root.add_child(ocean)
	check(is_equal_approx(pool.get("waves/size"), 3.2) and is_equal_approx(ocean.get("waves/size"), 18), "Root controls lost preset values")
	pool.set("waves/size", 5.0)
	pool.set("waves/speed", 0.0)
	pool.set("caustics/speed", 2.5)
	pool.set("caustics/size", 0.25)
	pool.set("surface/refraction_amount", 0.04)
	pool.set("surface/intersection_fade_distance", 0.35)
	check(is_equal_approx(ocean.get("waves/size"), 18), "Editing one region changed another")
	check(pool.get_node("Surface").material_override.get_shader_parameter("wave_speed") == 0.0, "Wave speed did not reach the live material")
	check(pool.get_node("Caustics").material_override.get_shader_parameter("caustic_speed") == 2.5, "Caustics do not have an independent speed")
	check(pool.get_node("Caustics").material_override.get_shader_parameter("pattern_scale") == 4.0, "Caustic size must grow the pattern rather than its frequency")
	var packed := PackedScene.new()
	check(packed.pack(pool) == OK, "Could not pack edited water region")
	var path := "user://water-controls-test.tscn"
	check(ResourceSaver.save(packed, path) == OK, "Could not save edited water region")
	var reopened: Node3D = (load(path) as PackedScene).instantiate()
	root.add_child(reopened)
	check(reopened.get("waves/size") == 5.0 and reopened.get("waves/speed") == 0.0 and reopened.get("caustics/speed") == 2.5, "Inspector settings did not survive scene save/reopen")
	check(is_equal_approx(reopened.get_node("Surface").material_override.get_shader_parameter("refraction_strength"), 0.04), "Reopened settings did not reach the shader")
	check(is_equal_approx(reopened.get_node("Surface").material_override.get_shader_parameter("intersection_fade_distance"), 0.35), "Intersection fade did not survive save/reopen")
	reopened.free()
	pool.free()
	ocean.free()
	DirAccess.remove_absolute(path)
	print("MGS_WATER_CONTROLS_TEST failures=%d" % failures)
	quit(1 if failures else 0)
