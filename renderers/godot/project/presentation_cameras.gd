extends RefCounted

const PROPERTIES = ["projection", "keep_aspect", "near", "far", "h_offset", "v_offset", "cull_mask", "environment", "attributes"]
var cameras: Array[Dictionary] = []
var registration_errors := {}
var baseline := {}
var active_id := 0
var active_path := ""
var history_reset_pending := false

func register(camera: Camera3D, scope: String, clip: String) -> String:
	if not is_instance_valid(camera): return "Presentation camera is missing"
	unregister(camera)
	if scope not in ["gameplay", "clip", "always"]: return reject(camera, "Unknown presentation camera scope: " + scope)
	if scope == "clip":
		var error := validate_clip(clip)
		if not error.is_empty(): return reject(camera, error)
	elif not clip.is_empty(): return reject(camera, "Only clip-scoped cameras accept a clip ID")
	cameras.append({"camera":camera, "scope":scope, "clip":clip})
	return ""

static func validate_clip(clip: String) -> String:
	var pattern := RegEx.new()
	pattern.compile("^mgs/integral-j/disc[12]/demo/[0-9a-f]{8}$")
	return "Presentation camera needs an exact prepared cinematic clip ID" if pattern.search(clip) == null else ""

func unregister(camera: Camera3D) -> void:
	cameras = cameras.filter(func(entry): return is_instance_valid(entry.camera) and entry.camera != camera)
	if is_instance_valid(camera): registration_errors.erase(camera.get_instance_id())

func reject(owner_node: Node, message: String) -> String:
	registration_errors[owner_node.get_instance_id()] = message
	return message

func restore(camera: Camera3D) -> void:
	for property in baseline: camera.set(property, baseline[property])
	baseline.clear()

func apply(camera: Camera3D, context: Dictionary, metadata_layer: int) -> String:
	for id in registration_errors:
		if is_instance_id_valid(id): return registration_errors[id]
	registration_errors.clear()
	cameras = cameras.filter(func(entry): return is_instance_valid(entry.camera))
	var clip := "mgs/integral-j/disc%d/demo/%08x" % [context.get("disc", 0), context.get("sector", 0)] if context.get("active", false) else ""
	var selected: Camera3D
	for entry in cameras:
		var source: Camera3D = entry.camera
		if not is_instance_valid(source) or not source.is_inside_tree() or not source.is_visible_in_tree(): continue
		if entry.scope == "gameplay" and not clip.is_empty(): continue
		if entry.scope == "clip" and entry.clip != clip: continue
		if selected != null: return "Multiple presentation cameras are active: %s and %s" % [selected.get_path(), source.get_path()]
		selected = source
	var next_id := selected.get_instance_id() if selected != null else 0
	if selected != null:
		var error := validate(selected, camera)
		if not error.is_empty(): return error
		for property in PROPERTIES:
			baseline[property] = camera.get(property)
			camera.set(property, selected.get(property))
		camera.cull_mask &= ~metadata_layer
		camera.global_transform = selected.global_transform.orthonormalized()
		camera.fov = selected.fov
	if next_id != active_id:
		history_reset_pending = true
		active_id = next_id
		active_path = str(selected.get_path()) if selected != null else ""
		print("MGS_PRESENTATION_CAMERA owner=" + (active_path if selected != null else "native/clip"))
	if camera.is_inside_tree(): camera.make_current()
	return ""

static func validate(source: Camera3D, target: Camera3D) -> String:
	if source == target or source.get_viewport() != target.get_viewport(): return "Presentation camera must be a separate Camera3D in the rendered world viewport"
	if source.projection != Camera3D.PROJECTION_PERSPECTIVE: return "Presentation cameras currently require perspective projection"
	if not source.global_transform.is_finite() or source.global_basis.determinant() <= 0.000001: return "Presentation camera has an invalid transform"
	for value in [source.fov, source.near, source.far, source.h_offset, source.v_offset]:
		if not is_finite(value): return "Presentation camera has a non-finite lens value"
	if source.fov < 1.0 or source.fov >= 179.0 or source.near <= 0.0 or source.far <= source.near: return "Presentation camera has invalid lens/clipping values"
	return ""

func request_cut(camera: Camera3D) -> void:
	if is_instance_valid(camera) and camera.get_instance_id() == active_id: history_reset_pending = true

func consume_history_reset() -> bool:
	var result := history_reset_pending
	history_reset_pending = false
	return result
