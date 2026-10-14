extends SceneTree

const Router = preload("res://water_ripple_router.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func ring(center: Vector3, flagged: bool = true) -> PackedByteArray:
	var data := PackedByteArray()
	for face in 8:
		data.append_array(PackedInt32Array([42]).to_byte_array())
		for corner in 4:
			var angle := (face + (corner & 1)) * TAU / 8.0
			var radius := 1.0 if corner < 2 else 1.2
			var point := center + Vector3(cos(angle), 0, sin(angle)) * radius
			data.append_array(PackedFloat32Array([point.x, point.y, point.z, 0.001, 0, 0, 0.25, 0.25, 0.25, 65 if flagged else 1, 0, 0]).to_byte_array())
	return data

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var water: Node3D = load("res://addons/mgs_water/water_region.tscn").instantiate()
	root.add_child(water)
	var owner_node := Node3D.new()
	root.add_child(owner_node)
	owner_node.transform = Transform3D(Basis(Vector3.RIGHT, PI), Vector3(1, 2, 3))
	var center := owner_node.to_local(Vector3.ZERO)
	var data := ring(center)
	data.append_array(ring(center + Vector3(15, 0, 0)))
	data.append_array(ring(center, false))
	var router := Router.new()
	router.route(owner_node, data, 0, 24)
	check(router.error.is_empty() and router.skipped.size() == 8, "Ripple ownership swallowed an outside or unrelated effect")
	var material: ShaderMaterial = water.get_node("Surface").material_override
	check(material.get_shader_parameter("ripple_count") == 1, "Native ring did not reach the surface material")
	var rings: PackedVector4Array = material.get_shader_parameter("ripple_rings")
	check(absf(rings[0].x) < 0.001 and absf(rings[0].y) < 0.001 and is_equal_approx(rings[0].z, 1.1), "Native camera transform or ring radius lost")
	water.hide()
	router.route(owner_node, data, 0, 24)
	check(router.skipped.is_empty() and material.get_shader_parameter("ripple_count") == 0, "Hidden water swallowed native ripples")
	water.show()
	router.route(owner_node, PackedByteArray(), 0, 0)
	check(material.get_shader_parameter("ripple_count") == 0, "Expired native ripple remained")
	check(water.add_ripple(Vector3.ZERO), "Authored ripple rejected")
	water.set_water_time(0.5)
	rings = material.get_shader_parameter("ripple_rings")
	check(rings[0].z > 1.0, "Authored disturbance did not propagate")
	water.set_water_time(5.0)
	check(material.get_shader_parameter("ripple_count") == 0, "Authored disturbance did not expire")
	var invalid := ring(center).slice(0, 196)
	router.route(owner_node, invalid, 0, 1)
	check(not router.error.is_empty(), "Truncated native ring accepted")
	water.free()
	owner_node.free()
	print("MGS_WATER_RIPPLE_TEST failures=", failures)
	quit(1 if failures else 0)
