extends SceneTree

const Preview = preload("res://cinematic_source.gd")
const Catalog = preload("res://addons/mgs_editor/scene_catalog.gd")
const Content = preload("res://content_catalog.gd")
const DiscMap = preload("res://addons/mgs_editor/disc_map.gd")
const Authoring = preload("res://addons/mgs_editor/map_authoring.gd")
const Coordinates = preload("res://map_coordinates.gd")
const Export = preload("res://addons/mgs_editor/mod_export.gd")
const Edits = preload("res://camera_edits.gd")
const Playback = preload("res://cinematic_camera.gd")
const CLIP = "mgs/integral-j/disc1/demo/00000000"
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	if "--originals" in OS.get_cmdline_user_args():
		check_originals()
	else:
		check_fixture()
	print("MGS_CINEMATIC_PREVIEW_TEST failures=%d" % failures)
	quit(1 if failures else 0)

func check_fixture() -> void:
	var directory := "user://cinematic-preview-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	var file := directory.path_join("clip.json")
	var rows := [[1, 1000, 2000, 3000, 1000, 2000, 4000, 0, 320], [3, 4000, 5000, 6000, 4000, 5000, 7000, 1024, 160]]
	FileAccess.open(file, FileAccess.WRITE).store_string(JSON.stringify({"schema":1, "id":CLIP, "camera":rows}))
	var prepared := {"disc":1, "assets":{}, "maps":{"opening":{"models":[], "clips":[{"id":CLIP, "models":[], "missing_models":[]}]}},
		"cinematics":{CLIP:{"path":"clip.json", "prepared_sha256":FileAccess.get_sha256(file), "sha256":"ab".repeat(32), "declared_frames":3}}}
	check(Preview.Catalog.validate_files(directory, prepared).is_empty(), "Valid camera source rejected")
	var reference := Node3D.new()
	check(Preview.attach(reference, directory, prepared, CLIP).is_empty(), "Cannot attach original camera")
	var overlay := Node3D.new()
	Coordinates.mark_editor(overlay)
	overlay.set_meta("mgs_scene_source", Catalog.source(prepared, "opening", CLIP))
	root.add_child(overlay)
	Authoring.new().attach_reference(overlay, reference)
	var camera := reference.get_node("OriginalCamera") as Camera3D
	check(camera.global_position.is_equal_approx(Vector3(1, 2, 3)), "Preview camera used the renderer's inverted editor axes")
	check((-camera.global_basis.z).is_equal_approx(Vector3.BACK), "Preview camera looks away from the original target")
	check(camera.global_basis.y.is_equal_approx(Vector3.UP), "Preview camera is upside down")
	var player := reference.get_node("OriginalCameraTimeline") as AnimationPlayer
	player.play("Original")
	player.seek(2.0 / Preview.FPS, true)
	check(camera.global_position.is_equal_approx(Vector3(1, 2, 3)), "Camera interpolated across a discrete source cut")
	player.seek(3.0 / Preview.FPS, true)
	check(camera.global_position.is_equal_approx(Vector3(4, 5, 6)) and is_equal_approx(camera.fov, 90.0), "Camera seek lost source pose or lens")
	check(camera.global_basis.y.is_equal_approx(Vector3.LEFT), "Source camera roll direction is wrong")
	var vertical := Coordinates.ROTATION * Preview.pose([1, 0, 0, 0, 0, 1000, 0, 0, 320])
	check(vertical.basis.x.is_equal_approx(Vector3.LEFT) and (-vertical.basis.z).is_equal_approx(Vector3.UP), "Vertical camera lost the native zero-yaw orientation")
	var authored := OmniLight3D.new()
	authored.name = "MyLight"
	overlay.add_child(authored)
	authored.owner = overlay
	var session := overlay.get_node("_MapSession")
	session.prepare_save()
	var packed := PackedScene.new()
	check(packed.pack(overlay) == OK and ResourceSaver.save(packed, directory.path_join("scene.tscn")) == OK, "Cannot save mod with a cinematic reference")
	session.finish_save()
	var saved := FileAccess.get_file_as_string(directory.path_join("scene.tscn"))
	check("MyLight" in saved and CLIP in saved and not "OriginalCamera" in saved, "Saved mod lost authored content or included original camera keys")
	var manifest := directory.path_join("mod.json")
	FileAccess.open(manifest, FileAccess.WRITE).store_string('{"schema":1,"id":"test.cinematic","stages":{"disc1/opening":{"scene":"scene.tscn"}}}')
	check(Export.new().export_mod(manifest, directory.path_join("mod.zip")).is_empty(), "Cinematic reference cannot export")
	var zip := ZIPReader.new()
	check(zip.open(directory.path_join("mod.zip")) == OK, "Cannot reopen cinematic mod ZIP")
	check("clip.json" not in zip.get_files() and not "OriginalCamera" in zip.read_file("scene.tscn").get_string_from_utf8(), "ZIP contains original camera data")
	zip.close()
	check_edits(session, reference, overlay, prepared, directory, player, manifest)
	var copied := directory.path_join("copied.tres")
	check(ResourceSaver.save(player.get_animation_library(""), copied) == OK, "Cannot create copied-animation rejection fixture")
	var exporter := Export.new()
	exporter.root = ProjectSettings.globalize_path(directory)
	exporter.collect(copied)
	check(exporter.error.contains("original geometry or a local preview"), "Copied original camera animation could be exported")
	var source: Dictionary = overlay.get_meta("mgs_scene_source")
	prepared.cinematics[CLIP].sha256 = "cd".repeat(32)
	check(not Catalog.source_error(source, prepared, "opening").is_empty(), "Changed original clip silently reopened")
	FileAccess.open(file, FileAccess.WRITE).store_string("changed")
	check(not Preview.Catalog.validate_files(directory, prepared).is_empty(), "Modified prepared track accepted")
	var attached := Node3D.new()
	attached.position = Vector3(0, 0, -1)
	camera.add_child(attached)
	attached.owner = overlay
	var position := attached.global_position
	session.detach_for_reload()
	session.free()
	reference.free()
	check(is_instance_valid(attached) and attached.get_parent() == overlay and attached.global_position.is_equal_approx(position), "Reloading a clip lost a custom node attached to its original preview")
	overlay.free()

func check_edits(session: Node, reference: Node3D, overlay: Node3D, prepared: Dictionary, directory: String, player: AnimationPlayer, manifest: String) -> void:
	check(session.attach_camera(reference, Preview.Catalog.source(prepared, CLIP)).is_empty(), "Cannot initialize sparse camera editing")
	var original: Animation = player.get_animation("Original").duplicate()
	var animation := player.get_animation("Original")
	var changed: Transform3D = animation.track_get_key_value(0, 1)
	changed.origin.x += 2.0
	animation.track_set_key_value(0, 1, changed)
	animation.add_marker("Elevator", 3.0 / Preview.FPS)
	animation.set_marker_color("Elevator", Color.CORNFLOWER_BLUE)
	session.prepare_save()
	var packed := PackedScene.new()
	check(packed.pack(overlay) == OK and ResourceSaver.save(packed, directory.path_join("scene.tscn")) == OK, "Cannot save sparse camera keys")
	session.finish_save()
	var edits: Dictionary = overlay.get_meta("mgs_camera_edits")
	check(edits[CLIP].tracks.size() == 1 and edits[CLIP].tracks["0"].keys.size() == 1 and edits[CLIP].tracks["0"].keys.has("3"), "Camera save copied unchanged original keys")
	check(edits[CLIP].cuts.Elevator.frame == 3, "Camera cut marker was not saved")
	check(Export.new().export_mod(manifest, directory.path_join("edited.zip")).is_empty(), "Camera edits cannot export")
	var zip := ZIPReader.new()
	check(zip.open(directory.path_join("edited.zip")) == OK, "Cannot reopen edited camera ZIP")
	var text := zip.read_file("scene.tscn").get_string_from_utf8()
	check(not "OriginalCamera" in text and not "Animation" in text and zip.get_files().size() == 2, "Edited ZIP contains the original timeline")
	FileAccess.open(directory.path_join("reopened.tscn"), FileAccess.WRITE).store_string(text)
	zip.close()
	var reopened: Node3D = load(directory.path_join("reopened.tscn")).instantiate()
	var content := Content.new()
	content.root = directory
	content.catalogs[1] = prepared
	var playback := Playback.new()
	var playback_error := playback.configure(reopened.get_meta("mgs_camera_edits"), content)
	check(playback_error.is_empty(), "Reopened camera cannot resolve original source: " + playback_error)
	var camera := Camera3D.new()
	var context := {"active":1, "disc":1, "sector":0, "total":3, "frame":2}
	check(playback.apply(context, camera, 1.0).is_empty(), "Native-frame sampling failed")
	check(playback.consume_history_reset(), "Entering authored clip did not request a history reset")
	check(camera.transform.is_equal_approx(original.track_get_key_value(0, 0)), "Native camera interpolation crossed a discrete cut")
	context.frame = 3
	check(playback.apply(context, camera, 0.75).is_empty() and camera.transform.is_equal_approx(changed), "Native source frame did not apply the authored key")
	check(playback.consume_history_reset(), "Exported cut did not request a history reset")
	check(is_equal_approx(camera.fov, rad_to_deg(2.0 * atan(1.0 / 0.75))), "Camera edit lost widescreen lens scaling")
	context.active = 0
	camera.transform = Transform3D.IDENTITY
	check(playback.apply(context, camera, 1.0).is_empty() and camera.transform == Transform3D.IDENTITY and playback.active_clip.is_empty(), "Completed/skipped clip retained camera ownership")
	var restored := Edits.restore(original, edits[CLIP], prepared.cinematics[CLIP].sha256)
	check(not restored.has("error") and restored.animation.track_get_key_value(0, 1).is_equal_approx(changed), "Editor reopen lost changed keys: " + str(restored.get("error", "")))
	check(restored.animation.has_marker("Elevator") and restored.animation.get_marker_color("Elevator") == Color.CORNFLOWER_BLUE, "Editor reopen lost cut name/color")
	check(Edits.restore(original, edits[CLIP], "00".repeat(32)).has("error"), "Camera source mismatch was ignored")
	var continuous: Animation = original.duplicate()
	continuous.track_remove_key(0, 1)
	continuous.track_insert_key(0, 3.0 / Preview.FPS, changed)
	continuous.value_track_set_update_mode(0, Animation.UPDATE_CONTINUOUS)
	continuous.track_set_interpolation_type(0, Animation.INTERPOLATION_LINEAR)
	var changes := Edits.difference(original, continuous, "digest")
	var merged := Edits.restore(original, changes.edit, "digest")
	check(not merged.has("error"), "Continuous camera edits did not round trip")
	if not merged.has("error"):
		var middle: Transform3D = Playback.sample(merged.animation, 0, 2.0 / Preview.FPS)
		var start: Transform3D = original.track_get_key_value(0, 0)
		check(middle.origin.is_equal_approx(start.origin.lerp(changed.origin, 0.5)), "Continuous track did not interpolate authored keys")
	continuous.track_set_key_value(1, 0, NAN)
	check(Edits.difference(original, continuous, "digest").has("error"), "Non-finite camera keys accepted")
	animation.track_set_key_value(0, 1, original.track_get_key_value(0, 1))
	animation.remove_marker("Elevator")
	session.collect_camera_edits()
	check(not overlay.has_meta("mgs_camera_edits"), "Restoring original camera kept redundant keys")
	reopened.free()
	camera.free()

func check_originals() -> void:
	var content := Content.new()
	var error := content.load_root("res://../../../.local/godot-content")
	check(error.is_empty(), error)
	if not error.is_empty(): return
	for disc in [1, 2]:
		var prepared := content.for_disc(disc)
		var loaded := 0
		for clip in prepared.cinematics:
			var reference := Node3D.new()
			check(Preview.attach(reference, content.root, prepared, clip).is_empty(), "Cannot build source camera: " + clip)
			reference.free()
		for stage in ["opening", "s07b"]:
			for binding in prepared.maps[stage].clips:
				check(Catalog.availability(prepared, content.root, stage, binding.id).is_empty(), "Cinematic scenery unavailable: " + binding.id)
				var loader := DiscMap.new()
				var map := loader.load_map(content.root, prepared, stage, "", binding.id)
				check(map != null, loader.error)
				if map != null:
					map.free()
					loaded += 1
		print("MGS_CINEMATIC_ORIGINALS disc=%d cameras=%d scene_sets=%d" % [disc, prepared.cinematics.size(), loaded])
