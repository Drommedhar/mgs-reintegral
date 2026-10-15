extends SceneTree

const Timeline = preload("res://examples/presentation_camera/native_timeline.gd")
const API = preload("res://visual_mod_api.gd")
const Export = preload("res://addons/mgs_editor/mod_export.gd")
const CLIP = "mgs/integral-j/disc1/demo/00001234"
var api := API.new()
var target := Camera3D.new()
var failures := 0

class Sentinel extends Node3D:
	var calls := 0
	func called() -> void: calls += 1

class FixtureScene extends Node3D:
	var content := preload("res://content_catalog.gd").new()

func check(value: bool, message: String) -> void:
	if value: return
	failures += 1
	push_error(message)

func _initialize() -> void:
	run.call_deferred()

func fixture(script: Script = Timeline) -> Node3D:
	var rig: Node3D = script.new()
	rig.name = "AuthoredTimeline"
	rig.clip_id = CLIP
	var pivot := Node3D.new()
	pivot.name = "Pivot"
	rig.add_child(pivot)
	rig.camera = Camera3D.new()
	rig.camera.name = "Camera"
	pivot.add_child(rig.camera)
	rig.player = AnimationPlayer.new()
	rig.player.name = "Player"
	rig.add_child(rig.player)
	var animation := Animation.new()
	animation.length = 2.0
	animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(0, NodePath("Pivot:position"))
	animation.track_insert_key(0, 0, Vector3.ZERO)
	animation.track_insert_key(0, 2, Vector3(6, 0, 0))
	animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(1, NodePath("Pivot/Camera:fov"))
	animation.track_insert_key(1, 0, 60.0)
	animation.track_insert_key(1, 2, 100.0)
	animation.add_marker("Cut", 1.0)
	animation.add_marker("SubframeCut", 0.51)
	var library := AnimationLibrary.new()
	library.add_animation(&"Camera", animation)
	rig.player.add_animation_library(&"", library)
	rig.player.autoplay = "Camera"
	return rig

func sample(frame: int, active: bool = true, generation: int = 1, epoch: int = 1) -> String:
	api.native_context = {"epoch":epoch,"cinematic":{"active":active,"disc":1,"sector":0x1234,"frame":frame,"total":61,"generation":generation}}
	api.presentation_cameras.restore(target)
	target.transform = Transform3D.IDENTITY
	target.fov = 60
	api.camera_update_requested.emit()
	return api.presentation_cameras.apply(target, api.native_context.cinematic, 1 << 19)

func run() -> void:
	root.add_child(api)
	root.add_child(target)
	var rig := fixture()
	rig.transform = Transform3D(Basis(Vector3.UP, PI/2), Vector3(10, 2, 3))
	root.add_child(rig)
	check(rig.player.autoplay.is_empty() and not rig.player.is_playing(), "Native timeline autoplay was not disabled")
	check(sample(-1).is_empty() and target.transform == Transform3D.IDENTITY, "Timeline took ownership before native time was available")
	check(sample(0).is_empty() and target.global_transform.is_equal_approx(rig.camera.global_transform), "Timeline did not enter at the native frame")
	check(api.presentation_cameras.consume_history_reset(), "Timeline entry retained camera history")
	check(sample(15).is_empty() and rig.get_node("Pivot").position.is_equal_approx(Vector3(1.5,0,0)) and is_equal_approx(target.fov, 70), "Timeline did not sample native frame/30 or lens values")
	check(not api.presentation_cameras.consume_history_reset(), "Continuous native frames reset camera history")
	var paused_pose := target.global_transform
	check(sample(15).is_empty() and target.global_transform.is_equal_approx(paused_pose) and not api.presentation_cameras.consume_history_reset(), "Repeated native frame advanced or reset the camera")
	check(sample(16).is_empty() and api.presentation_cameras.consume_history_reset(), "Fractional-frame marker crossing missed its cut")
	check(sample(40).is_empty() and rig.get_node("Pivot").position.is_equal_approx(Vector3(4,0,0)), "Skipped native frames were integrated instead of sampled")
	check(api.presentation_cameras.consume_history_reset(), "Skipped-frame marker crossing missed its cut")
	check(sample(40).is_empty() and not api.presentation_cameras.consume_history_reset(), "Paused cut reset history repeatedly")
	check(sample(40, true, 2).is_empty() and api.presentation_cameras.consume_history_reset(), "Same clip restart retained history")
	check(sample(10, true, 2, 2).is_empty() and api.presentation_cameras.consume_history_reset(), "Epoch/backward seek retained history")
	var unchanged := api.native_context.duplicate(true)
	rig.synchronize()
	check(api.native_context == unchanged, "Camera timeline mutated native timing")
	check(sample(60).is_empty() and is_equal_approx(target.fov, 100), "Final native frame did not reach the final authored key")
	check(sample(60, false).is_empty() and target.transform == Transform3D.IDENTITY and is_equal_approx(target.fov, 60), "Clip finish/abort retained camera ownership")
	check(sample(0).is_empty(), "Cannot reacquire timeline camera")
	rig.enabled = false
	check(api.presentation_cameras.cameras.is_empty(), "Disabled timeline retained camera ownership")
	rig.enabled = true
	check(sample(0).is_empty(), "Re-enabled timeline did not reacquire camera")
	rig.free()
	check(api.presentation_cameras.cameras.is_empty(), "Retired timeline retained camera registration")
	check_invalid_tracks()
	check_missing_clip()
	check_zip_roundtrip()
	var example := preload("res://examples/presentation_camera/native_timeline.tscn").instantiate()
	example.clip_id = CLIP
	root.add_child(example)
	check(example.validate().is_empty() and sample(15).is_empty() and is_equal_approx(target.fov, 61.25), "Distributed timeline example did not resolve its player/camera or keys")
	example.free()
	target.free()
	api.free()
	print("MGS_NATIVE_CAMERA_TIMELINE_TEST failures=%d" % failures)
	quit(1 if failures else 0)

func check_invalid_tracks() -> void:
	var rig := fixture()
	var sentinel := Sentinel.new()
	sentinel.name = "Sentinel"
	rig.add_child(sentinel)
	var animation: Animation = rig.player.get_animation(&"Camera")
	var track := animation.add_track(Animation.TYPE_METHOD)
	animation.track_set_path(track, NodePath("Sentinel"))
	animation.track_insert_key(track, 0, {"method":&"called", "args":[]})
	root.add_child(rig)
	check(sentinel.calls == 0 and "native events" in sample(0), "Unsafe autoplay/method track ran or was silently accepted")
	animation.remove_track(track)
	animation.track_set_path(0, NodePath("../Outside:position"))
	check("inside this timeline rig" in sample(0), "Track outside the rig was accepted")
	animation.track_set_path(0, NodePath(".:position"))
	check("child pivot" in sample(0), "Timeline root track could overwrite coordinate conversion")
	animation.track_set_path(0, NodePath("Pivot:position"))
	animation.value_track_set_update_mode(0, Animation.UPDATE_CAPTURE)
	check("Capture tracks" in sample(0), "History-dependent capture track was accepted")
	animation.value_track_set_update_mode(0, Animation.UPDATE_CONTINUOUS)
	animation.loop_mode = Animation.LOOP_LINEAR
	check("must not loop" in sample(0), "Looping timeline was accepted")
	animation.loop_mode = Animation.LOOP_NONE
	animation.length = 3
	check("native clip duration" in sample(0), "Timeline silently retimed the native clip")
	rig.enabled = false
	check(sample(0).is_empty(), "Disabled timeline retained a validation error")
	rig.free()

func check_missing_clip() -> void:
	api.scene = FixtureScene.new()
	var rig := fixture()
	rig.clip_id = "mgs/integral-j/disc1/demo/deadbeef"
	root.add_child(rig)
	check("not prepared" in sample(0, false) and "not prepared" in rig.binding_status, "Unprepared timeline silently waited for a nonexistent clip")
	api.scene.content.catalogs[1] = {"cinematics":{CLIP:{}}}
	rig.clip_id = CLIP
	check(sample(15).is_empty() and is_equal_approx(target.fov, 70), "A prepared clip could not acquire its authored timeline")
	rig.free()
	api.scene.free()
	api.scene = null

func own(node: Node, scene: Node) -> void:
	for child in node.get_children():
		child.owner = scene
		own(child, scene)

func check_zip_roundtrip() -> void:
	var directory := "user://native-camera-timeline-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	var script := directory.path_join("native_timeline.gd")
	check(DirAccess.copy_absolute("res://examples/presentation_camera/native_timeline.gd", script) == OK, "Cannot copy native timeline SDK script")
	var rig := fixture(load(script))
	own(rig, rig)
	var packed := PackedScene.new()
	check(packed.pack(rig) == OK and ResourceSaver.save(packed, directory.path_join("timeline.tscn")) == OK, "Cannot save authored camera timeline")
	rig.free()
	FileAccess.open(directory.path_join("mod.json"), FileAccess.WRITE).store_string(JSON.stringify({"schema":1,"id":"test.native-camera-timeline","stages":{"d00a":{"scene":"timeline.tscn"}}}))
	var archive := directory.path_join("mod.zip")
	check(Export.new().export_mod(directory.path_join("mod.json"), archive).is_empty(), "Camera timeline ZIP export failed")
	var zip := ZIPReader.new()
	check(zip.open(archive) == OK and zip.get_files().size() == 3, "Camera timeline ZIP dependency closure changed")
	var installed := directory.path_join("installed")
	DirAccess.make_dir_recursive_absolute(installed)
	for file in zip.get_files(): FileAccess.open(installed.path_join(file), FileAccess.WRITE).store_buffer(zip.read_file(file))
	zip.close()
	var restored := load(installed.path_join("timeline.tscn")).instantiate() as Node3D
	root.add_child(restored)
	check(restored.validate().is_empty() and sample(15).is_empty() and is_equal_approx(target.fov, 70), "Reopened native timeline lost its player, camera, keys or native sampling")
	restored.free()
