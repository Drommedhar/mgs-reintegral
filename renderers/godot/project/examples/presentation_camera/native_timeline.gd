@tool
extends Node3D

const FPS = 30.0
const TRANSFORMS = ["position", "rotation", "rotation_degrees", "quaternion", "scale", "transform"]
const LENS = ["fov", "near", "far", "h_offset", "v_offset"]
@export var camera: Camera3D
@export var player: AnimationPlayer
@export var animation_name: StringName = &"Camera"
@export var clip_id := ""
@export var enabled := true:
	set(value):
		enabled = value
		if is_instance_valid(api): synchronize()
var api: Node
var active_camera: Camera3D
var previous_frame := -1
var previous_generation := -1
var previous_epoch := -1
var binding_status := "Editor preview"

func _enter_tree() -> void:
	if Engine.is_editor_hint(): return
	if is_instance_valid(player) and is_ancestor_of(player):
		player.autoplay = ""
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		player.active = true
		player.stop()

func _ready() -> void:
	if Engine.is_editor_hint(): return
	api = get_tree().get_first_node_in_group("mgs_visual_api_v1")
	if api == null:
		binding_status = "Native game is not connected"
		return
	api.camera_update_requested.connect(synchronize)
	synchronize()

func validate() -> String:
	if not is_instance_valid(camera) or not is_ancestor_of(camera): return "Choose a Camera3D inside this timeline rig"
	if not is_instance_valid(player) or not is_ancestor_of(player): return "Choose an AnimationPlayer inside this timeline rig"
	var pattern := RegEx.new()
	pattern.compile("^mgs/integral-j/disc[12]/demo/[0-9a-f]{8}$")
	if pattern.search(clip_id) == null: return "Choose an exact prepared cinematic clip ID"
	if is_instance_valid(api):
		var error: String = api.validate_presentation_clip(clip_id)
		if not error.is_empty(): return error
	if not player.has_animation(animation_name): return "Camera animation is missing: " + str(animation_name)
	if not player.root_motion_track.is_empty(): return "Camera timelines do not extract root motion"
	var animation := player.get_animation(animation_name)
	if animation.loop_mode != Animation.LOOP_NONE: return "Camera timelines must not loop"
	var animation_root := player.get_node_or_null(player.root_node)
	if animation_root == null or (animation_root != self and not is_ancestor_of(animation_root)): return "Animation root must be inside this timeline rig"
	for track in animation.get_track_count():
		var error := validate_track(animation, track, animation_root)
		if not error.is_empty(): return "Camera track %d: %s" % [track, error]
	return ""

func validate_track(animation: Animation, track: int, animation_root: Node) -> String:
	var path := animation.track_get_path(track)
	var node := animation_root.get_node_or_null(NodePath(path.get_concatenated_names()))
	if node == self: return "Animate a child pivot or camera to preserve the timeline root's coordinate conversion"
	if not node is Node3D or not is_ancestor_of(node): return "Target must be a Node3D inside this timeline rig"
	match animation.track_get_type(track):
		Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D:
			if path.get_subname_count() != 0: return "Transform tracks must target a node"
		Animation.TYPE_VALUE:
			if path.get_subname_count() != 1: return "Value tracks must target a transform or camera lens property"
			var property := str(path.get_subname(0))
			if property not in TRANSFORMS and not (node is Camera3D and property in LENS): return "Only transform and camera lens properties are supported"
			if animation.value_track_get_update_mode(track) == Animation.UPDATE_CAPTURE: return "Capture tracks depend on prior playback state"
		_:
			return "Only transform and lens tracks are supported; native events and audio remain authoritative"
	return ""

func synchronize() -> void:
	if not is_instance_valid(api): return
	var error := validate() if enabled else ""
	api.set_presentation_camera_error(self, error)
	if not enabled or not error.is_empty():
		release()
		binding_status = error if enabled else "Disabled"
		return
	var context: Dictionary = api.get_native_context()
	var clip: Dictionary = context.get("cinematic", {})
	var identity := "mgs/integral-j/disc%d/demo/%08x" % [clip.get("disc", 0), clip.get("sector", 0)]
	var frame: int = clip.get("frame", -1)
	if not clip.get("active", false) or identity != clip_id or frame < 0:
		release()
		binding_status = "Waiting for native clip"
		return
	var animation := player.get_animation(animation_name)
	if clip.get("total", 0) <= 0 or roundi(animation.length * FPS) > int(clip.total):
		release()
		binding_status = "Authored animation exceeds the native clip duration"
		api.set_presentation_camera_error(self, binding_status)
		return
	if active_camera != camera:
		release()
		error = api.register_presentation_camera(camera, "clip", clip_id)
		if not error.is_empty():
			binding_status = error
			api.unregister_presentation_camera(camera)
			api.set_presentation_camera_error(self, error)
			return
		active_camera = camera
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	if player.assigned_animation != animation_name: player.assigned_animation = animation_name
	player.seek(frame / FPS, true, true)
	var generation: int = clip.get("generation", 0)
	var epoch: int = context.get("epoch", 0)
	var cut := generation != previous_generation or epoch != previous_epoch or frame < previous_frame
	var marker := animation.get_prev_marker(frame / FPS)
	if frame > previous_frame and not marker.is_empty(): cut = cut or animation.get_marker_time(marker) > previous_frame / FPS
	if cut: api.request_camera_cut(camera)
	previous_frame = frame
	previous_generation = generation
	previous_epoch = epoch
	binding_status = "Native frame %d" % frame

func release() -> void:
	if is_instance_valid(api) and is_instance_valid(active_camera): api.unregister_presentation_camera(active_camera)
	active_camera = null
	previous_frame = -1
	previous_generation = -1
	previous_epoch = -1

func _exit_tree() -> void:
	if is_instance_valid(api):
		api.camera_update_requested.disconnect(synchronize)
		release()
		api.set_presentation_camera_error(self, "")
	request_ready()
