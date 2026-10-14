extends SceneTree

const Edits = preload("res://camera_edits.gd")
const Playback = preload("res://cinematic_camera.gd")
const CLIP = "mgs/integral-j/disc1/demo/00000000"
var failures := 0

func check(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)

func _initialize() -> void:
	run.call_deferred()

func original() -> Animation:
	var animation := Animation.new()
	animation.length = 1.0
	for track in 2:
		animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track, Edits.PATHS[track])
		animation.value_track_set_update_mode(track, Animation.UPDATE_CONTINUOUS)
		for frame in [0, 10, 20, 30]:
			var value: Variant = Transform3D(Basis.IDENTITY, Vector3(frame, 0, 0)) if track == 0 else 60.0 + frame
			animation.track_insert_key(track, frame / Edits.FPS, value)
	return animation

func run() -> void:
	var base := original()
	var edited: Animation = base.duplicate()
	edited.add_marker("Shot two", 20.0 / Edits.FPS)
	check(Edits.difference(base, edited, "digest").has("error"), "Continuous camera cuts silently interpolated across shots")
	for track in 2: edited.track_set_key_transition(track, 1, 0.0)
	var delta := Edits.difference(base, edited, "digest")
	check(not delta.has("error"), "Cut with hold keys rejected")
	if delta.has("error"):
		quit(1)
		return
	check(delta.edit.tracks["0"].keys.is_empty() and delta.edit.tracks["1"].keys.is_empty(), "Hold-only edits copied original camera values")
	var marker_only: Animation = base.duplicate()
	for track in 2: marker_only.value_track_set_update_mode(track, Animation.UPDATE_DISCRETE)
	var discrete: Animation = marker_only.duplicate()
	marker_only.add_marker("Only a cut", 20.0 / Edits.FPS)
	var marker_delta := Edits.difference(discrete, marker_only, "digest")
	check(marker_delta.edit.tracks.is_empty() and marker_delta.edit.cuts.size() == 1, "Marker-only mod copied original tracks")
	check(not Edits.restore(discrete, marker_delta.edit, "digest").has("error"), "Marker-only mod failed to restore")
	var restored := Edits.restore(base, delta.edit, "digest")
	check(not restored.has("error"), "Cut/hold edits failed to restore")
	if restored.has("error"):
		quit(1)
		return
	var animation: Animation = restored.animation
	check_sampling(animation)
	check_lifecycle(animation)
	var invalid: Dictionary = delta.edit.duplicate(true)
	invalid.cuts["Shot two"].frame = 19
	check(Edits.restore(base, invalid, "digest").has("error"), "Cut without paired camera keys accepted")
	invalid.cuts["Shot two"].frame = 31
	check(Edits.restore(base, invalid, "digest").has("error"), "Cut past source duration accepted")
	invalid.cuts["Shot two"].frame = NAN
	check(Edits.restore(base, invalid, "digest").has("error"), "Non-finite cut accepted")
	invalid = delta.edit.duplicate(true)
	invalid.tracks["0"].holds["9"] = 0.0
	check(Edits.restore(base, invalid, "digest").has("error"), "Hold on absent key accepted")
	edited.remove_marker("Shot two")
	edited.add_marker("Fractional", 0.51)
	check(Edits.difference(base, edited, "digest").has("error"), "Subframe cut accepted")
	print("MGS_CAMERA_CUTS_TEST failures=%d" % failures)
	quit(1 if failures else 0)

func check_sampling(animation: Animation) -> void:
	var reference := Node3D.new()
	var camera := Camera3D.new()
	camera.name = "OriginalCamera"
	reference.add_child(camera)
	var player := AnimationPlayer.new()
	reference.add_child(player)
	root.add_child(reference)
	var library := AnimationLibrary.new()
	library.add_animation("Edited", animation)
	player.add_animation_library("", library)
	player.play("Edited")
	for frame in [5.0, 19.0, 19.5, 20.0, 25.0]:
		var expected: float = 10.0 if frame > 10.0 and frame < 20.0 else frame
		player.seek(frame / Edits.FPS, true)
		var pose: Transform3D = Playback.sample(animation, 0, frame / Edits.FPS)
		check(is_equal_approx(pose.origin.x, expected) and camera.transform.is_equal_approx(pose), "Preview and native-frame camera differ at frame %.1f" % frame)
		check(is_equal_approx(camera.fov, 60.0 + expected), "Lens blended across cut at frame %.1f" % frame)
	reference.free()

func check_lifecycle(animation: Animation) -> void:
	var playback := Playback.new()
	playback.animations[CLIP] = {"animation":animation, "total":30}
	var camera := Camera3D.new()
	var context := {"active":1, "generation":1, "disc":1, "sector":0, "total":30, "frame":0}
	var frames := [0, 0, 19, 25, 25, 30]
	var cuts := [true, false, false, true, false, false]
	for index in frames.size():
		context.frame = frames[index]
		var before := context.duplicate(true)
		check(playback.apply(context, camera, 1.0).is_empty(), "Camera playback failed")
		check(playback.consume_history_reset() == cuts[index], "Wrong cut reset at sample %d" % index)
		check(context == before, "Camera changed native clip timing")
	context.generation = 2
	context.frame = 0
	playback.apply(context, camera, 1.0)
	check(playback.consume_history_reset(), "Restart of the same clip retained old history")
	context.active = 0
	camera.transform = Transform3D.IDENTITY
	playback.apply(context, camera, 1.0)
	check(playback.consume_history_reset() and playback.active_clip.is_empty() and camera.transform == Transform3D.IDENTITY, "Skip/end did not release ownership and history")
	playback.apply(context, camera, 1.0)
	check(not playback.consume_history_reset(), "Inactive clip continuously reset history")
	context.active = 1
	context.sector = 1
	playback.apply(context, camera, 1.0)
	check(playback.consume_history_reset() and playback.active_clip.is_empty(), "Native-only clip transition retained old history")
	context.sector = 0
	playback.apply(context, camera, 1.0)
	check(playback.configure({}, null).is_empty(), "Stage unload did not clear edits")
	playback.apply(context, camera, 1.0)
	check(playback.consume_history_reset() and playback.active_clip.is_empty(), "Stage unload retained authored ownership")
	camera.free()
