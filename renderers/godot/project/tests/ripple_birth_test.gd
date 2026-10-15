extends SceneTree

var failures := 0

func check(value: bool, message: String) -> void:
	if value: return
	failures += 1
	push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var water: Node3D = load("res://addons/mgs_water/water_region.tscn").instantiate()
	root.add_child(water)
	var material: ShaderMaterial = water.get_node("Surface").material_override
	water.add_ripple(Vector3.ZERO)
	var born: PackedVector4Array = material.get_shader_parameter("ripple_rings")
	check(absf(born[0].w) < 0.001, "Authored ripple appears at full strength on its birth frame")
	water.set_water_time(0.12)
	var grown: PackedVector4Array = material.get_shader_parameter("ripple_rings")
	check(grown[0].w > 0.02, "Authored ripple never develops")
	water.ripples.clear()
	water.begin_native_ripples()
	water.native_ripple(Vector3.ZERO, 0.3, 0.12, 0.5)
	water.finish_native_ripples()
	born = material.get_shader_parameter("ripple_rings")
	check(absf(born[0].w) < 0.001, "Native ripple appears at full strength on its birth frame")
	water.clock.seconds = 0.12
	water.begin_native_ripples()
	water.native_ripple(Vector3.ZERO, 0.5, 0.12, 0.5)
	water.finish_native_ripples()
	grown = material.get_shader_parameter("ripple_rings")
	check(grown[0].w > 0.02, "Native ripple does not retain its birth time while expanding")
	water.begin_native_ripples()
	water.native_ripple(Vector3.ZERO, 0.5, 0.12, 0.5)
	water.native_ripple(Vector3.ZERO, 0.1, 0.12, 0.5)
	water.finish_native_ripples()
	var overlapping: PackedVector4Array = material.get_shader_parameter("ripple_rings")
	check(is_equal_approx(overlapping[0].w, grown[0].w), "Paused ripple changed strength")
	check(is_zero_approx(overlapping[1].w), "New concentric ripple inherited the old ring's age")
	water.begin_native_ripples()
	water.finish_native_ripples()
	water.begin_native_ripples()
	water.native_ripple(Vector3.ZERO, 0.5, 0.12, 0.5)
	water.finish_native_ripples()
	born = material.get_shader_parameter("ripple_rings")
	check(is_zero_approx(born[0].w), "Expired ripple left stale birth history")
	water.free()
	print("MGS_RIPPLE_BIRTH_TEST failures=", failures)
	quit(1 if failures else 0)
