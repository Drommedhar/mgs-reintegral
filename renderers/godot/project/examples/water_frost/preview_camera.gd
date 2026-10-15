extends Camera3D

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var origin := project_ray_origin(event.position)
		var direction := project_ray_normal(event.position)
		for water in get_tree().get_nodes_in_group("mgs_water_regions"):
			var plane := Plane(water.global_basis.y.normalized(), water.global_position)
			var hit = plane.intersects_ray(origin, direction)
			if hit != null and water.add_ripple(hit): break
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		rotation.y -= event.relative.x * 0.003
		rotation.x = clampf(rotation.x - event.relative.y * 0.003, -1.5, 1.5)

func _process(delta: float) -> void:
	var move := Vector3(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	position += basis * move.normalized() * delta * (15.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 4.0)
