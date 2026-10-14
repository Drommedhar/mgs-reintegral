extends RefCounted

const LIMIT := 16
const RISE_SECONDS := 0.12
var disturbances: Array[Dictionary] = []
var native_rings: Array[Vector4] = []
var native_widths: Array[float] = []
var native_history: Array[Dictionary] = []

func clear() -> void:
	disturbances.clear()
	native_rings.clear()
	native_widths.clear()
	native_history.clear()

func finish_native(seconds: float) -> void:
	var next: Array[Dictionary] = []
	var matched: Dictionary = {}
	for ring in native_rings:
		var best := -1
		var distance := INF
		for index in native_history.size():
			if matched.has(index): continue
			var previous: Dictionary = native_history[index]
			var age: float = seconds - previous.sample_time
			if age < 0 or age > 0.2 or ring.z + 0.01 < previous.ring.z: continue
			var movement := Vector2(ring.x - previous.ring.x, ring.y - previous.ring.y).length()
			var expansion: float = ring.z - previous.ring.z
			var score: float = movement + expansion
			if movement <= 0.05 and expansion <= 0.05 + age * 20.0 and score < distance:
				best = index
				distance = score
		var born: float = seconds if best < 0 else native_history[best].born
		if best >= 0: matched[best] = true
		next.append({"ring":ring, "born":born, "sample_time":seconds})
	native_history = next

func add(position: Vector2, seconds: float, strength: float, width: float, speed: float) -> void:
	if disturbances.size() == LIMIT: disturbances.pop_front()
	disturbances.append({"position":position, "time":seconds, "strength":strength, "width":width, "speed":speed})

func apply(material: ShaderMaterial, seconds: float) -> void:
	var rings := PackedVector4Array()
	var widths := PackedFloat32Array()
	disturbances = disturbances.filter(func(entry): return seconds >= entry.time and seconds - entry.time < 4.0)
	for entry in disturbances:
		var age: float = seconds - entry.time
		rings.append(Vector4(entry.position.x, entry.position.y, age * entry.speed, entry.strength * smoothstep(0.0, RISE_SECONDS, age) * exp(-age * 1.4)))
		widths.append(entry.width)
	for index in mini(native_rings.size(), LIMIT - rings.size()):
		var ring := native_rings[index]
		if index < native_history.size(): ring.w *= smoothstep(0.0, RISE_SECONDS, seconds - float(native_history[index].born))
		rings.append(ring)
		widths.append(native_widths[index])
	material.set_shader_parameter("ripple_count", rings.size())
	rings.resize(LIMIT)
	widths.resize(LIMIT)
	material.set_shader_parameter("ripple_rings", rings)
	material.set_shader_parameter("ripple_widths", widths)
