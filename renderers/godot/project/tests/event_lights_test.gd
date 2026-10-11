extends SceneTree

const EventLights = preload("res://event_lights.gd")
const Templates = preload("res://event_light_templates.gd")
var failures := 0
var viewport := SubViewport.new()
var lights := EventLights.new()

func check(condition: bool, message: String) -> void:
	if condition: return
	push_error(message)
	failures += 1

func payload(kind: int, position: Vector3 = Vector3(-2, 4, 2)) -> PackedByteArray:
	var direction := Vector3.ZERO if kind == 4 else -position.normalized()
	var bytes := PackedInt32Array([1, 1 if kind == 1 else kind + 7, kind]).to_byte_array()
	bytes.append_array(PackedFloat32Array([position.x, position.y, position.z, direction.x, direction.y, direction.z, 8, 12]).to_byte_array())
	return bytes

func frame() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func darker(before: Image, after: Image, threshold: float = 0.04) -> int:
	var pixels := 0
	for y in before.get_height():
		for x in before.get_width():
			if before.get_pixel(x, y).get_luminance() - after.get_pixel(x, y).get_luminance() > threshold: pixels += 1
	return pixels

func _initialize() -> void:
	call_deferred("run")

func check_lifetime() -> void:
	check(lights.update_lights(payload(1), 0).is_empty(), "Temporary light rejected")
	var flash: Light3D = lights.instances[1].node
	check(lights.update_lights(PackedInt32Array([0]).to_byte_array(), 0).is_empty(), "Empty lights rejected")
	check(not flash.visible and lights.active_count == 0, "Expired flash kept lighting the scene")
	check(lights.update_lights(payload(1, Vector3(2, 3, 4)), 0).is_empty(), "Reused native light slot rejected")
	check(lights.instances[1].node == flash and flash.position == Vector3(2, 3, 4), "Flash allocation or position was stale")
	var small := payload(1)
	small.encode_float(36, 0.25)
	check(lights.update_lights(small, 0).is_empty() and flash.omni_range == 0.5, "Native shrinking radius was lost")
	check(lights.update_lights(payload(2, Vector3.UP), 0).is_empty(), "Vertical weapon direction rejected")
	var weapon: SpotLight3D = lights.instances[9].node
	check((-weapon.basis.z).is_equal_approx(Vector3.DOWN), "Weapon spotlight does not follow the barrel")
	check(lights.update_lights(PackedInt32Array([0]).to_byte_array(), 0).is_empty(), "Weapon retirement rejected")
	check(not lights.instances.has(9), "Retired weapon light leaked")
	var invalid := payload(2)
	invalid.encode_float(12, NAN)
	check(not lights.update_lights(invalid, 0).is_empty(), "Nonfinite light position accepted")
	check(not lights.update_lights(payload(1).slice(0, 40), 0).is_empty(), "Truncated light accepted")
	var duplicate := payload(1)
	duplicate.encode_u32(0, 2)
	duplicate.append_array(payload(1).slice(4))
	check(not lights.update_lights(duplicate, 0).is_empty(), "Duplicate light identity accepted")
	check(lights.configure(null).is_empty() and lights.instances.is_empty(), "Stage change retained event lights")
	var pair := payload(3)
	pair.encode_u32(0, 3)
	var other := payload(3)
	other.encode_u32(4, 20)
	for axis in 3: other.encode_float(24 + axis * 4, -pair.decode_float(24 + axis * 4))
	pair.append_array(other.slice(4))
	var fill := payload(4, Vector3(2, 3, 4))
	fill.encode_u32(4, 11)
	pair.append_array(fill.slice(4))
	check(lights.update_lights(pair, 0).is_empty() and lights.active_count == 3, "Alarm did not create both spotlights and one fill")
	var first: SpotLight3D = lights.instances[10].node
	var second: SpotLight3D = lights.instances[20].node
	check(first.basis.z.is_equal_approx(-second.basis.z), "Alarm spotlights do not point in opposing directions")
	check(first.light_color.r > first.light_color.g * 10 and second.shadow_enabled, "Alarm lost red light or shadows")
	var omni: OmniLight3D = lights.instances[11].node
	check(omni.position == Vector3(2, 3, 4) and omni.omni_range == 6 and omni.shadow_enabled, "Alarm fill lost its authored range, position or shadows")
	check(omni.light_energy < first.light_energy * 0.1, "Alarm fill overpowers the rotating beams")
	check(lights.update_lights(PackedInt32Array([0]).to_byte_array(), 0).is_empty() and lights.instances.is_empty(), "Inactive alarm retained a light")

func run() -> void:
	viewport.size = Vector2i(192, 192)
	viewport.own_world_3d = true
	viewport.positional_shadow_atlas_size = 2048
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(lights)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.position = Vector3(0, 7, 7)
	camera.look_at(Vector3.ZERO)
	camera.environment = Environment.new()
	camera.environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	floor_mesh.mesh.size = Vector2(12, 12)
	viewport.add_child(floor_mesh)
	var blocker := MeshInstance3D.new()
	blocker.mesh = BoxMesh.new()
	blocker.scale = Vector3(0.7, 2, 0.5)
	blocker.position.y = 1
	blocker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	viewport.add_child(blocker)
	var overlay := Node3D.new()
	viewport.add_child(overlay)
	Templates.attach(overlay)
	var group := overlay.get_node(Templates.GROUP)
	group.get_node("TemporaryFlash").omni_range = 12
	group.get_node("WeaponSpot").spot_angle = 35
	check(lights.configure(overlay).is_empty(), "Authored light templates rejected")
	check(not group.visible and not lights.templates.visible, "Template lamps lit the map directly")
	for kind in [1, 2, 3, 4]:
		var data := payload(kind, Vector3(-1, 2.5, 1) if kind == 4 else Vector3(-2, 4, 2))
		var threshold := 0.008 if kind == 4 else 0.04
		check(lights.update_lights(data, 0).is_empty(), "Native light snapshot rejected")
		var id: int = 1 if kind == 1 else kind + 7
		check(lights.instances[id].node.shadow_enabled, "Event light lost shadows")
		blocker.hide()
		var illuminated := await frame()
		check(lights.update_lights(PackedInt32Array([0]).to_byte_array(), 0).is_empty(), "Cannot clear event lights")
		check(darker(illuminated, await frame(), threshold) > 200, "Event light does not illuminate geometry")
		check(lights.update_lights(data, 0).is_empty(), "Cannot restore event light")
		blocker.show()
		var pixels := darker(illuminated, await frame(), threshold)
		print("MGS_EVENT_SHADOW kind=%d pixels=%d" % [kind, pixels])
		check(pixels > 30, "Event light does not cast shadows")
	group.get_node("AlarmSpot").free()
	group.get_node("AlarmFill").free()
	check(lights.configure(overlay).is_empty() and lights.templates.has_node("AlarmSpot") and lights.templates.has_node("AlarmFill"), "Older mod ZIP lacks default alarm lights")
	check(lights.templates.get_node("WeaponSpot").spot_angle == 35, "Alarm migration changed authored weapon light")
	check(Templates.attach(overlay) and group.has_node("AlarmSpot") and group.has_node("AlarmFill"), "Editor did not add the new alarm templates")
	check_lifetime()
	viewport.free()
	print("MGS_EVENT_LIGHTS_TEST failures=%d" % failures)
	quit(1 if failures else 0)
