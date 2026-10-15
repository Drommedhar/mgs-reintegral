@tool
extends RefCounted

const FPS = 30.0

static func key_at_frame(animation: Animation, track: int, frame: int) -> int:
	var low := 0
	var high := animation.track_get_key_count(track)
	while low < high:
		var middle := (low + high) / 2
		if roundi(animation.track_get_key_time(track, middle) * FPS) < frame: low = middle + 1
		else: high = middle
	return low if low < animation.track_get_key_count(track) and roundi(animation.track_get_key_time(track, low) * FPS) == frame else -1

static func read(animation: Animation) -> Dictionary:
	var cuts := {}
	for name in animation.get_marker_names():
		cuts[name] = {"frame":roundi(animation.get_marker_time(name) * FPS), "color":animation.get_marker_color(name)}
	return cuts

static func validate(animation: Animation) -> String:
	for name in animation.get_marker_names():
		var time := animation.get_marker_time(name)
		var color := animation.get_marker_color(name)
		if name.is_empty() or not color.is_equal_approx(color.clamp()): return "Camera cut needs a name and a finite color between 0 and 1"
		if not is_finite(time) or time < 0 or time > animation.length or not is_equal_approx(time * FPS, round(time * FPS)):
			return "Camera cut markers must use source frames within the original duration"
		for track in 2:
			var key := key_at_frame(animation, track, roundi(time * FPS))
			if key < 0: return "Key both transform and FOV at camera cut: " + name
			if key > 0 and animation.value_track_get_update_mode(track) == Animation.UPDATE_CONTINUOUS and animation.track_get_key_transition(track, key - 1) != 0.0:
				return "Set the key before cut '%s' to easing 0 on continuous camera tracks" % name
	return ""

static func restore(animation: Animation, cuts: Variant) -> String:
	if not cuts is Dictionary: return "Camera cuts must be named frame markers"
	for name in animation.get_marker_names(): animation.remove_marker(name)
	var used := {}
	for name in cuts:
		var cut = cuts[name]
		if not name is String or name.is_empty() or not cut is Dictionary or not cut.get("frame") is int or not cut.get("color") is Color:
			return "Invalid camera cut marker"
		if used.has(cut.frame) or cut.frame < 0 or cut.frame > roundi(animation.length * FPS) or not cut.color.is_equal_approx(cut.color.clamp()):
			return "Camera cut frame or color is invalid or duplicated"
		used[cut.frame] = true
		animation.add_marker(name, cut.frame / FPS)
		animation.set_marker_color(name, cut.color)
	return ""
