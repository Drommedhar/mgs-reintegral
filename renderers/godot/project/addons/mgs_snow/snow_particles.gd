@tool
extends RefCounted

var positions := PackedVector3Array()
var contacts := PackedVector3Array()
var normals := PackedVector3Array()
var bodies: Array[RID] = []
var states := PackedByteArray()
var ages := PackedFloat32Array()
var seeds := PackedFloat32Array()
var buffer := PackedFloat32Array()
var random := RandomNumberGenerator.new()
var mesh := MultiMesh.new()
var time := 0.0
var initial := true

func _init() -> void:
	mesh.transform_format = MultiMesh.TRANSFORM_3D
	mesh.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mesh.mesh = quad

func reset(amount: int, seed_value: int) -> void:
	mesh.instance_count = 0
	positions.resize(amount)
	contacts.resize(amount)
	normals.resize(amount)
	bodies.resize(amount)
	states.resize(amount)
	states.fill(0)
	ages.resize(amount)
	ages.fill(0)
	seeds.resize(amount)
	buffer.resize(amount * 16)
	buffer.fill(0)
	random.seed = seed_value
	for index in amount: seeds[index] = random.randf()
	mesh.instance_count = amount
	mesh.buffer = buffer
	time = 0.0
	initial = true

func land(index: int, hit: Dictionary, volume: Node3D, collision: RefCounted) -> void:
	var normal: Vector3 = hit.normal
	var point: Vector3 = hit.position + normal * volume.contact_offset
	positions[index] = volume.to_local(point)
	bodies[index] = hit.rid
	var transform: Transform3D = collision.bodies[hit.rid].transform
	contacts[index] = transform.affine_inverse() * point
	normals[index] = transform.basis.transposed() * normal
	states[index] = 2
	ages[index] = 0

func spawn(index: int, volume: Node3D, collision: RefCounted) -> void:
	var size: Vector3 = volume.volume_size
	var point := Vector3(random.randf_range(-size.x * 0.5, size.x * 0.5), size.y * 0.5, random.randf_range(-size.z * 0.5, size.z * 0.5))
	states[index] = 1
	ages[index] = 0
	positions[index] = point
	if initial and volume.prewarm:
		point.y = random.randf_range(-size.y * 0.5, size.y * 0.5)
		var hit: Dictionary = collision.cast(volume.to_global(positions[index]), volume.to_global(point))
		if hit.is_empty(): positions[index] = point
		else: land(index, hit, volume, collision)

func step(delta: float, volume: Node3D, collision: RefCounted) -> void:
	time += delta
	var size: Vector3 = volume.volume_size
	var wind: Vector3 = volume.wind_velocity
	var gust: float = sin(time * volume.gust_speed) * volume.gust_strength
	if not wind.is_zero_approx(): wind += wind.normalized() * gust
	for index in positions.size():
		if states[index] == 0: spawn(index, volume, collision)
		if states[index] == 2:
			settle(index, delta, volume, collision)
		else:
			fall(index, delta, wind, volume, collision)
		var position := positions[index]
		if absf(position.x) > size.x * 0.5 or absf(position.z) > size.z * 0.5 or absf(position.y) > size.y * 0.5: states[index] = 0
		write_instance(index, volume, collision)
	mesh.buffer = buffer
	initial = false

func fall(index: int, delta: float, wind: Vector3, volume: Node3D, collision: RefCounted) -> void:
	var seed_value := seeds[index]
	var phase := seed_value * TAU
	var flutter: Vector3 = Vector3(sin(time * volume.flutter_speed + phase), 0, cos(time * volume.flutter_speed * 0.83 + phase * 1.7)) * volume.flutter_strength
	var velocity: Vector3 = wind + flutter
	velocity.y -= volume.fall_speed * lerpf(1.0 - volume.speed_variation, 1.0 + volume.speed_variation, seed_value)
	var next := positions[index] + velocity * delta
	var hit: Dictionary = collision.cast(volume.to_global(positions[index]), volume.to_global(next))
	if hit.is_empty(): positions[index] = next
	else: land(index, hit, volume, collision)

func settle(index: int, delta: float, volume: Node3D, collision: RefCounted) -> void:
	ages[index] += delta
	var point: Variant = collision.contact(bodies[index], contacts[index])
	if point == null or ages[index] >= volume.settle_time:
		states[index] = 0
		return
	positions[index] = volume.to_local(point)

func write_instance(index: int, volume: Node3D, collision: RefCounted) -> void:
	var scale_value: float = lerpf(volume.flake_size.x, volume.flake_size.y, seeds[index])
	var basis := Basis.IDENTITY
	if states[index] == 2 and collision.bodies.has(bodies[index]):
		var transform: Transform3D = collision.bodies[bodies[index]].transform
		var normal: Vector3 = volume.global_basis.transposed() * (transform.basis.inverse().transposed() * normals[index])
		normal = normal.normalized()
		basis = Basis.looking_at(-normal, Vector3.RIGHT if absf(normal.y) > 0.99 else Vector3.UP)
	basis = basis.scaled(Vector3.ONE * scale_value)
	var offset := index * 16
	buffer[offset] = basis.x.x
	buffer[offset + 1] = basis.y.x
	buffer[offset + 2] = basis.z.x
	buffer[offset + 3] = positions[index].x
	buffer[offset + 4] = basis.x.y
	buffer[offset + 5] = basis.y.y
	buffer[offset + 6] = basis.z.y
	buffer[offset + 7] = positions[index].y
	buffer[offset + 8] = basis.x.z
	buffer[offset + 9] = basis.y.z
	buffer[offset + 10] = basis.z.z
	buffer[offset + 11] = positions[index].z
	buffer[offset + 12] = seeds[index]
	buffer[offset + 13] = 0.0 if states[index] == 0 else (1.0 - smoothstep(0.0, volume.settle_time, ages[index]) if states[index] == 2 else 1.0)
	buffer[offset + 14] = 1.0 if states[index] == 2 else 0.0
	buffer[offset + 15] = 0.0
