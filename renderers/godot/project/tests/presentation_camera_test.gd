extends SceneTree

const Cameras = preload("res://presentation_cameras.gd")
const API = preload("res://visual_mod_api.gd")
const Export = preload("res://addons/mgs_editor/mod_export.gd")
const Coordinates = preload("res://map_coordinates.gd")
const CLIP = "mgs/integral-j/disc2/demo/00001234"
var controller := Cameras.new()
var target := Camera3D.new()
var failures := 0

func check(value: bool, message: String) -> void:
	if value: return
	failures += 1
	push_error(message)

func _initialize() -> void:
	run.call_deferred()

func update(context: Dictionary = {}) -> String:
	controller.restore(target)
	target.transform = Transform3D.IDENTITY
	target.fov = 60
	return controller.apply(target, context, 1 << 19)

func run() -> void:
	root.add_child(target)
	target.near = 0.01
	var rig := Camera3D.new()
	root.add_child(rig)
	rig.position = Vector3(3, 4, 5)
	rig.fov = 90
	rig.near = 0.5
	rig.environment = Environment.new()
	check(controller.register(rig, "gameplay", "").is_empty(), "Gameplay camera registration failed")
	check(update().is_empty() and target.position == rig.position and target.fov == 90, "Authored camera not applied")
	check(target.environment == rig.environment and target.near == 0.5 and not target.cull_mask & (1 << 19), "Lens/environment/internal layer not handled")
	check(controller.consume_history_reset(), "Camera entry retained history")
	rig.position.x += 1
	check(update().is_empty() and target.position == rig.position and not controller.consume_history_reset(), "Continuous rig motion reset history")
	controller.request_cut(rig)
	check(controller.consume_history_reset() and not controller.consume_history_reset(), "Explicit cut was not one-shot")
	var context := {"active":true, "disc":2, "sector":0x1234, "frame":0}
	check(update(context).is_empty() and target.transform == Transform3D.IDENTITY and target.environment == null and is_equal_approx(target.near, 0.01), "Gameplay rig blocked a cinematic or leaked settings")
	check(controller.consume_history_reset(), "Camera release retained history")
	check(controller.register(rig, "clip", CLIP).is_empty(), "Clip camera registration failed")
	check(update(context).is_empty() and target.position == rig.position, "Exact clip camera not applied")
	context.sector = 0x1235
	check(update(context).is_empty() and target.transform == Transform3D.IDENTITY, "Clip camera affected another clip")
	context.active = false
	check(update(context).is_empty() and target.transform == Transform3D.IDENTITY, "Clip camera remained after skip/finish")
	check(controller.register(rig, "always", "").is_empty(), "Always camera rejected")
	var other := Camera3D.new()
	root.add_child(other)
	controller.register(other, "always", "")
	check("Multiple presentation cameras" in update(), "Conflicting cameras were silently selected")
	other.hide()
	check(update().is_empty() and target.position == rig.position, "Hidden rig still competed")
	other.free()
	rig.projection = Camera3D.PROJECTION_ORTHOGONAL
	check("perspective" in update(), "Unsupported projection was silently accepted")
	rig.projection = Camera3D.PROJECTION_PERSPECTIVE
	check(not controller.register(rig, "clip", "unknown").is_empty() and not update().is_empty(), "Invalid registration silently fell back")
	controller.unregister(rig)
	check(update().is_empty() and target.position == Vector3.ZERO, "Unregistered camera retained ownership")
	check_invalid_cameras(rig)
	rig.free()
	check_zip_roundtrip()
	target.free()
	print("MGS_PRESENTATION_CAMERA_TEST failures=%d" % failures)
	quit(1 if failures else 0)

func check_invalid_cameras(rig: Camera3D) -> void:
	var api := API.new()
	var scene := Node3D.new()
	scene.set_script(preload("res://scene_view.gd"))
	root.add_child(scene)
	api.scene = scene
	check("not prepared" in api.register_presentation_camera(rig, "clip", CLIP), "Unprepared cinematic binding accepted")
	check("not prepared" in api.presentation_cameras.apply(target, {}, 1 << 19), "Invalid cinematic binding silently fell back")
	api.unregister_presentation_camera(rig)
	scene.free()
	api.free()
	var viewport := SubViewport.new()
	root.add_child(viewport)
	var other := Camera3D.new()
	viewport.add_child(other)
	controller.register(other, "always", "")
	check("viewport" in update(), "Camera from another viewport accepted")
	viewport.free()
	controller.register(rig, "gameplay", "")
	rig.scale = Vector3.ZERO
	check("transform" in update(), "Singular camera transform accepted")
	rig.scale = Vector3.ONE
	controller.unregister(rig)

func check_zip_roundtrip() -> void:
	var directory := "user://camera-rig-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	check(DirAccess.copy_absolute("res://examples/presentation_camera/camera.gd", directory.path_join("camera.gd")) == OK, "Cannot copy camera SDK script")
	var overlay := Node3D.new()
	Coordinates.mark_editor(overlay)
	var rig := Camera3D.new()
	rig.name = "AuthoredCamera"
	rig.set_script(load(directory.path_join("camera.gd")))
	rig.position = Vector3(3, 4, 5)
	overlay.add_child(rig)
	rig.owner = overlay
	var packed := PackedScene.new()
	check(packed.pack(overlay) == OK and ResourceSaver.save(packed, directory.path_join("stage.tscn")) == OK, "Cannot save authored camera")
	var manifest := {"schema":1,"id":"test.camera-rig","stages":{"disc2/s12c":{"scene":"stage.tscn"}}}
	FileAccess.open(directory.path_join("mod.json"), FileAccess.WRITE).store_string(JSON.stringify(manifest))
	var archive := directory.path_join("mod.zip")
	check(Export.new().export_mod(directory.path_join("mod.json"), archive).is_empty(), "Camera ZIP export failed")
	var zip := ZIPReader.new()
	check(zip.open(archive) == OK and zip.get_files().size() == 3, "Camera ZIP contains unexpected dependencies")
	var installed := directory.path_join("installed")
	DirAccess.make_dir_recursive_absolute(installed)
	for file in zip.get_files(): FileAccess.open(installed.path_join(file), FileAccess.WRITE).store_buffer(zip.read_file(file))
	zip.close()
	overlay.free()
	var api := API.new()
	root.add_child(api)
	var restored := load(installed.path_join("stage.tscn")).instantiate() as Node3D
	Coordinates.to_runtime(restored)
	root.add_child(restored)
	check(api.presentation_cameras.cameras.size() == 1, "Reopened camera did not register")
	check(api.presentation_cameras.apply(target, {}, 1 << 19).is_empty() and target.global_position.is_equal_approx(Vector3(3, -4, -5)), "Saved editor coordinates differ in runtime")
	var camera: Camera3D = restored.get_node("AuthoredCamera")
	camera.enabled = false
	api.presentation_cameras.restore(target)
	check(api.presentation_cameras.cameras.is_empty(), "Disabling camera did not release it")
	camera.enabled = true
	check(api.presentation_cameras.cameras.size() == 1, "Enabling camera failed to reacquire it")
	restored.free()
	check(api.presentation_cameras.cameras.is_empty(), "Stage retirement retained its camera")
	api.free()
