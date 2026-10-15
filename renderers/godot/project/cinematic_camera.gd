extends RefCounted

const Preview = preload("res://cinematic_source.gd")
const Edits = preload("res://camera_edits.gd")
var animations := {}
var active_clip := ""
var history_reset_pending := false
var previous_clip := ""
var previous_generation := -1
var previous_frame := -1
var previous_authored := false

func configure(edits: Dictionary, content: RefCounted) -> String:
	animations.clear()
	active_clip = ""
	history_reset_pending = true
	for clip in edits:
		if not clip is String or clip.split("/").size() != 5: return "Invalid camera clip identity"
		var disc: int = clip.get_slice("/", 2).trim_prefix("disc").to_int()
		var prepared: Dictionary = content.for_disc(disc)
		var source := Preview.Catalog.source(prepared, clip)
		if source.is_empty() or not edits[clip] is Dictionary: return "Missing original camera source: " + clip
		var reference := Node3D.new()
		var error := Preview.attach(reference, content.root, prepared, clip)
		if not error.is_empty():
			reference.free()
			return error
		var original: Animation = reference.get_node("OriginalCameraTimeline").get_animation("Original")
		var result := Edits.restore(original, edits[clip], source.sha256)
		reference.free()
		if result.has("error"): return result.error + ": " + clip
		animations[clip] = {"animation":result.animation, "total":int(prepared.cinematics[clip].declared_frames)}
	return ""

static func sample(animation: Animation, track: int, time: float) -> Variant:
	if animation.value_track_get_update_mode(track) == Animation.UPDATE_CONTINUOUS:
		return animation.value_track_interpolate(track, time)
	var low := 0
	var high := animation.track_get_key_count(track)
	while low < high:
		var middle := (low + high) / 2
		if roundi(animation.track_get_key_time(track, middle) * Edits.FPS) <= roundi(time * Edits.FPS): low = middle + 1
		else: high = middle
	return animation.track_get_key_value(track, maxi(0, low - 1))

func apply(context: Dictionary, camera: Camera3D, horizontal_scale: float) -> String:
	active_clip = ""
	var identity := ""
	if context.get("active", false) and context.get("frame", -1) >= 0:
		identity = "mgs/integral-j/disc%d/demo/%08x" % [context.disc, context.sector]
	var animation: Animation
	if animations.has(identity):
		if animations[identity].total != context.total: return "Native cinematic duration differs from prepared camera: " + identity
		animation = animations[identity].animation
	observe(context, identity, animation)
	if animation == null: return ""
	var time: float = context.frame / Edits.FPS
	var transform: Transform3D = sample(animation, 0, time)
	var fov: float = sample(animation, 1, time)
	camera.transform = transform
	camera.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(fov) / 2.0) / horizontal_scale))
	active_clip = identity
	return ""

func observe(context: Dictionary, identity: String, animation: Animation) -> void:
	var generation: int = context.get("generation", 0)
	var frame: int = context.get("frame", -1) if not identity.is_empty() else -1
	if identity != previous_clip or generation != previous_generation or frame < previous_frame or (animation != null) != previous_authored:
		history_reset_pending = true
	elif animation != null and frame > previous_frame:
		var marker := animation.get_prev_marker(frame / Edits.FPS)
		if not marker.is_empty() and roundi(animation.get_marker_time(marker) * Edits.FPS) > previous_frame:
			history_reset_pending = true
	previous_clip = identity
	previous_generation = generation
	previous_frame = frame
	previous_authored = animation != null

func consume_history_reset() -> bool:
	var pending := history_reset_pending
	history_reset_pending = false
	return pending
