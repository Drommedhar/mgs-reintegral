@tool
extends RefCounted

const FPS = 30.0
const Cuts = preload("res://camera_cuts.gd")
const PATHS = ["OriginalCamera:transform", "OriginalCamera:fov"]

static func same(a: Variant, b: Variant) -> bool:
	return a.is_equal_approx(b) if a is Transform3D and b is Transform3D else is_equal_approx(a, b)

static func value_error(track: int, value: Variant) -> String:
	if track == 0:
		if not value is Transform3D or not value.is_finite() or not value.basis.is_equal_approx(value.basis.orthonormalized()) or value.basis.determinant() < 0.99:
			return "Camera transform must be finite with an unscaled rotation"
	elif (not value is float and not value is int) or not is_finite(value) or value < 1 or value > 179:
		return "Camera FOV must be between 1 and 179 degrees"
	return ""

static func validate(animation: Animation, original: Animation) -> String:
	if animation == null: return "Restore OriginalCameraTimeline's Original animation before saving"
	if animation.get_track_count() != 2 or animation.loop_mode != Animation.LOOP_NONE or not is_equal_approx(animation.length, original.length):
		return "Camera edits must retain the two pose/lens tracks, source duration and no looping"
	for track in 2:
		if animation.track_get_type(track) != Animation.TYPE_VALUE or str(animation.track_get_path(track)) != PATHS[track] or not animation.track_is_enabled(track):
			return "Camera tracks must target OriginalCamera transform and fov"
		if animation.value_track_get_update_mode(track) not in [Animation.UPDATE_DISCRETE, Animation.UPDATE_CONTINUOUS] or animation.track_get_interpolation_type(track) not in [Animation.INTERPOLATION_NEAREST, Animation.INTERPOLATION_LINEAR]:
			return "Camera tracks support discrete or continuous updates with nearest or linear interpolation"
		if animation.track_get_key_count(track) == 0: return "Camera tracks need at least one key"
		for key in animation.track_get_key_count(track):
			if animation.track_get_key_transition(track, key) not in [0.0, 1.0]:
				return "Camera key easing supports 0 (hold) or 1 (linear)"
			var time := animation.track_get_key_time(track, key)
			if time < 0 or roundi(time * FPS) > roundi(original.length * FPS) or not is_equal_approx(time * FPS, round(time * FPS)):
				return "Camera keys must use source frames at 30 FPS within the original duration"
			var error := value_error(track, animation.track_get_key_value(track, key))
			if not error.is_empty(): return error
	return Cuts.validate(animation)

static func keys(animation: Animation, track: int) -> Dictionary:
	var result := {}
	for key in animation.track_get_key_count(track):
		result[str(roundi(animation.track_get_key_time(track, key) * FPS))] = animation.track_get_key_value(track, key)
	return result

static func transitions(animation: Animation, track: int) -> Dictionary:
	var result := {}
	for key in animation.track_get_key_count(track):
		if animation.track_get_key_transition(track, key) == 0.0:
			result[str(roundi(animation.track_get_key_time(track, key) * FPS))] = 0.0
	return result

static func difference(original: Animation, edited: Animation, digest: String) -> Dictionary:
	var error := validate(edited, original)
	if not error.is_empty(): return {"error":error}
	var tracks := {}
	for track in 2:
		var base := keys(original, track)
		var next := keys(edited, track)
		var changed := {}
		var removed: Array[String] = []
		for frame in next:
			if not base.has(frame) or not same(base[frame], next[frame]): changed[frame] = next[frame]
		for frame in base:
			if not next.has(frame): removed.append(frame)
		var interpolation := edited.track_get_interpolation_type(track)
		var update := edited.value_track_get_update_mode(track)
		var holds := transitions(edited, track)
		if not changed.is_empty() or not removed.is_empty() or interpolation != original.track_get_interpolation_type(track) or update != original.value_track_get_update_mode(track) or holds != transitions(original, track):
			tracks[str(track)] = {"keys":changed, "removed":removed, "interpolation":interpolation, "update":update, "holds":holds}
	var cuts := Cuts.read(edited)
	var edit := {"sha256":digest, "tracks":tracks}
	if cuts != Cuts.read(original): edit.cuts = cuts
	return {"edit":{} if tracks.is_empty() and not edit.has("cuts") else edit}

static func restore(original: Animation, edit: Dictionary, digest: String) -> Dictionary:
	if edit.get("sha256") != digest or not edit.get("tracks") is Dictionary: return {"error":"Camera edit source changed or is invalid"}
	var animation := original.duplicate() as Animation
	for index in edit.tracks:
		if index not in ["0", "1"]: return {"error":"Unknown camera track"}
		var track := int(index)
		var patch = edit.tracks[index]
		if not patch is Dictionary or not patch.get("keys") is Dictionary or not patch.get("removed") is Array:
			return {"error":"Invalid sparse camera keys"}
		if patch.get("interpolation") not in [Animation.INTERPOLATION_NEAREST, Animation.INTERPOLATION_LINEAR] or patch.get("update") not in [Animation.UPDATE_DISCRETE, Animation.UPDATE_CONTINUOUS]:
			return {"error":"Unsupported camera interpolation"}
		var merged := keys(original, track)
		for frame in patch.removed:
			if not merged.has(frame): return {"error":"Removed camera key is absent from the original"}
			merged.erase(frame)
		for frame in patch.keys:
			if not frame is String or not frame.is_valid_int() or str(int(frame)) != frame: return {"error":"Invalid camera frame"}
			var error := value_error(track, patch.keys[frame])
			if not error.is_empty(): return {"error":error}
			merged[frame] = patch.keys[frame]
		for key in range(animation.track_get_key_count(track) - 1, -1, -1): animation.track_remove_key(track, key)
		for frame in merged: animation.track_insert_key(track, float(frame) / FPS, merged[frame])
		var holds = patch.get("holds", {})
		if not holds is Dictionary: return {"error":"Invalid camera hold keys"}
		for frame in holds:
			if not merged.has(frame) or holds[frame] != 0.0: return {"error":"Camera hold must name an existing key with easing 0"}
			animation.track_set_key_transition(track, Cuts.key_at_frame(animation, track, int(frame)), 0.0)
		animation.track_set_interpolation_type(track, patch.interpolation)
		animation.value_track_set_update_mode(track, patch.update)
	if edit.has("cuts"):
		var cut_error := Cuts.restore(animation, edit.cuts)
		if not cut_error.is_empty(): return {"error":cut_error}
	var error := validate(animation, original)
	return {"animation":animation} if error.is_empty() else {"error":error}
