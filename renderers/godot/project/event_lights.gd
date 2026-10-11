extends Node3D

const Templates = preload("res://event_light_templates.gd")
const RECORD_BYTES = 40
const LIGHT_LIMIT = 264
var templates: Node3D
var instances: Dictionary = {}
var active_count := 0

func configure(overlay: Node3D) -> String:
	var source := overlay.get_node_or_null(Templates.GROUP) if overlay != null else null
	if source != null:
		var error := Templates.validate(source)
		if not error.is_empty(): return error
	for entry in instances.values(): entry.node.free()
	instances.clear()
	active_count = 0
	if templates != null: templates.free()
	templates = Templates.create() if source == null else source.duplicate() as Node3D
	Templates.add_missing_alarms(templates)
	if source != null: source.hide()
	templates.hide()
	add_child(templates)
	return ""

func decode(payload: PackedByteArray, offset: int) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	var seen := {}
	for index in payload.decode_u32(offset):
		var start := offset + 4 + index * RECORD_BYTES
		var id := payload.decode_u32(start)
		var kind := payload.decode_u32(start + 4)
		var position := Vector3(payload.decode_float(start + 8), payload.decode_float(start + 12), payload.decode_float(start + 16))
		var direction := Vector3(payload.decode_float(start + 20), payload.decode_float(start + 24), payload.decode_float(start + 28))
		var radius := payload.decode_float(start + 32)
		var cutoff := payload.decode_float(start + 36)
		if id == 0 or seen.has(id) or not Templates.NAMES.has(kind): return []
		if instances.has(id) and instances[id].kind != kind: return []
		if (kind == 1) != (id <= 8): return []
		if not position.is_finite() or not direction.is_finite(): return []
		if not is_finite(radius) or not is_finite(cutoff) or radius < 0 or cutoff < 0: return []
		if kind == 1 and (radius == 0 or cutoff == 0): return []
		if kind in [2, 3] and direction.length_squared() < 0.0001: return []
		seen[id] = true
		states.append({"id": id, "kind": kind, "position": position, "direction": direction, "range": minf(radius * 2, cutoff)})
	return states

func update_lights(payload: PackedByteArray, offset: int) -> String:
	if payload.size() - offset < 4: return "Missing event light count"
	var count := payload.decode_u32(offset)
	if count > LIGHT_LIMIT or payload.size() - offset - 4 != count * RECORD_BYTES: return "Invalid event light payload"
	var states := decode(payload, offset)
	if states.size() != count: return "Invalid event light state"
	if templates == null:
		var error := configure(null)
		if not error.is_empty(): return error
	var seen := {}
	active_count = 0
	for entry in instances.values(): entry.node.hide()
	for state in states:
		seen[state.id] = true
		var prototype := templates.get_node(NodePath(Templates.NAMES[state.kind])) as Light3D
		if not instances.has(state.id):
			var node := prototype.duplicate() as Light3D
			node.name = "%s_%d" % [Templates.NAMES[state.kind], state.id]
			add_child(node)
			instances[state.id] = {"node": node, "kind": state.kind}
		var light: Light3D = instances[state.id].node
		var basis := Basis.IDENTITY
		if state.kind in [2, 3]:
			var direction: Vector3 = state.direction.normalized()
			basis = Basis.looking_at(direction, Vector3.RIGHT if absf(direction.y) > 0.99 else Vector3.UP)
		light.transform = Transform3D(basis, state.position) * prototype.transform
		if state.kind == 1: light.omni_range = minf(state.range, prototype.omni_range)
		light.visible = prototype.visible
		if light.visible: active_count += 1
	for id in instances.keys():
		if id <= 8 or seen.has(id): continue
		instances[id].node.free()
		instances.erase(id)
	return ""
