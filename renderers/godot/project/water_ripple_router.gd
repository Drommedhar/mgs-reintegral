extends RefCounted

const RIPPLE := 64
const QUAD_BYTES := 196
const RING_QUADS := 8
var regions: Array[Node] = []
var skipped: Dictionary = {}
var error := ""

func route(owner_node: Node3D, payload: PackedByteArray, offset: int, count: int) -> void:
	skipped.clear()
	error = ""
	regions.clear()
	if not owner_node.is_inside_tree(): return
	for region in owner_node.get_tree().get_nodes_in_group("mgs_water_regions"):
		if region.has_method("native_ripple"):
			regions.append(region)
			region.begin_native_ripples()
	if regions.is_empty(): return
	var quad := 0
	while quad < count:
		var start := offset + quad * QUAD_BYTES
		if not int(payload.decode_float(start + 40)) & RIPPLE:
			quad += 1
			continue
		if quad + RING_QUADS > count:
			error = "Incomplete native surface ripple"
			break
		var points := PackedVector3Array()
		var strength := 0.0
		for face in RING_QUADS:
			var face_start := start + face * QUAD_BYTES
			if not int(payload.decode_float(face_start + 40)) & RIPPLE or payload.decode_u32(face_start) != payload.decode_u32(start):
				error = "Native surface ripple contains unrelated quads"
				break
			strength += payload.decode_float(face_start + 28) / RING_QUADS
			for corner in 4:
				var vertex := face_start + 4 + corner * 48
				points.append(owner_node.to_global(Vector3(payload.decode_float(vertex), payload.decode_float(vertex + 4), payload.decode_float(vertex + 8))))
		if not error.is_empty(): break
		if consume(points, strength):
			for face in RING_QUADS: skipped[quad + face] = true
		quad += RING_QUADS
	for region in regions: region.finish_native_ripples()

func consume(points: PackedVector3Array, strength: float) -> bool:
	var center := Vector3.ZERO
	for point in points: center += point / points.size()
	var inner := INF
	var outer := 0.0
	for point in points:
		var radius := center.distance_to(point)
		inner = minf(inner, radius)
		outer = maxf(outer, radius)
	for region in regions:
		if region.native_ripple(center, (inner + outer) * 0.5, (outer - inner) * 0.5, strength): return true
	return false
