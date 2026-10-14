@tool
extends RefCounted

const Catalog = preload("res://cinematic_catalog.gd")
const FPS = 30.0

static func pose(row: Array) -> Transform3D:
	var axes := Vector3(1, -1, -1)
	var eye := Vector3(row[1], row[2], row[3]) * axes / 1000.0
	var target := Vector3(row[4], row[5], row[6]) * axes / 1000.0
	var direction := target - eye
	var transform := Transform3D(Basis.IDENTITY, eye)
	if direction.x == 0 and direction.z == 0:
		var back := -direction.normalized()
		transform.basis = Basis(Vector3.LEFT, back.cross(Vector3.LEFT), back)
	else:
		transform = transform.looking_at(target, Vector3.DOWN)
	transform.basis = transform.basis * Basis(Vector3.BACK, -float(row[7]) * TAU / 4096.0)
	return transform

static func attach(reference: Node3D, directory: String, prepared: Dictionary, clip: String) -> String:
	var data := Catalog.camera_data(directory, prepared, clip)
	if data.is_empty(): return "Prepared camera data is invalid or changed: " + clip
	var definition: Dictionary = prepared.cinematics[clip]
	var camera := Camera3D.new()
	camera.name = "OriginalCamera"
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.near = 0.01
	camera.far = 300.0
	camera.editor_description = "Local original camera. Edit transform/FOV keys in OriginalCameraTimeline; only changed keys are saved to the mod."
	var animation := Animation.new()
	animation.resource_name = "Original camera (local preview)"
	animation.set_meta("mgs_retail_derived", true)
	animation.length = maxf(1, definition.declared_frames) / FPS
	animation.step = 1.0 / FPS
	for property in ["transform", "fov"]:
		var track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track, NodePath("OriginalCamera:" + property))
		animation.value_track_set_update_mode(track, Animation.UPDATE_DISCRETE)
		animation.track_set_interpolation_type(track, Animation.INTERPOLATION_NEAREST)
	for row in data.camera:
		if row[8] <= 0 or row.slice(1, 4) == row.slice(4, 7): continue
		var transform := pose(row)
		var fov := rad_to_deg(2.0 * atan(160.0 / float(row[8])))
		if animation.track_get_key_count(0) == 0:
			camera.transform = transform
			camera.fov = fov
			camera.set_meta("first_camera_frame", int(row[0]))
		animation.track_insert_key(0, float(row[0]) / FPS, transform)
		animation.track_insert_key(1, float(row[0]) / FPS, fov)
	if animation.track_get_key_count(0) == 0:
		camera.free()
		return "Clip has no usable source camera keys: " + clip
	var library := AnimationLibrary.new()
	library.set_meta("mgs_retail_derived", true)
	library.add_animation("Original", animation)
	var player := AnimationPlayer.new()
	player.name = "OriginalCameraTimeline"
	player.add_animation_library("", library)
	player.editor_description = "Source frame / 30. Named Animation markers are hard cuts; key transform and FOV at each cut. For continuous tracks set the preceding key's easing to 0. No audio, actors or native events execute in preview."
	reference.add_child(camera)
	reference.add_child(player)
	return ""
