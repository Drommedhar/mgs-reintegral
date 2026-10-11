extends SceneTree

const Coordinates = preload("res://map_coordinates.gd")
const SceneView = preload("res://scene_view.gd")
const ASSET = "mgs/integral-j/disc1/stage/s00a/0001.k"
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func save_overlay(overlay: Node3D, path: String) -> void:
	var packed := PackedScene.new()
	check(packed.pack(overlay) == OK and ResourceSaver.save(packed, path) == OK, "Cannot save coordinate fixture")

func migration(directory: String, runtime: Node3D) -> void:
	var overlay := Node3D.new()
	root.add_child(overlay)
	overlay.transform = Transform3D(Basis.from_euler(Vector3(0.2, 0.4, 0.1)), Vector3(4, 5, 6))
	var container := Node.new()
	overlay.add_child(container)
	container.owner = overlay
	var object := MeshInstance3D.new()
	object.name = "AuthoredObject"
	object.mesh = BoxMesh.new()
	object.transform = Transform3D(Basis.from_euler(Vector3(0.1, 0.2, 0.3)), Vector3(1, 2, 3))
	container.add_child(object)
	object.owner = overlay
	var light := OmniLight3D.new()
	light.name = "AuthoredLight"
	light.position = Vector3(-1, 4, 7)
	object.add_child(light)
	light.owner = overlay
	var old_object := object.global_transform
	var old_light := light.global_transform
	var direct_light := OmniLight3D.new()
	direct_light.name = "DirectLight"
	direct_light.position = Vector3(2, 5, 8)
	overlay.add_child(direct_light)
	direct_light.owner = overlay
	var old_direct_light := direct_light.global_transform
	var rule := {"asset": ASSET, "anchor": Vector3(1, 2, 3), "part": 0}
	overlay.set_meta("mgs_removals", [rule])
	save_overlay(overlay, directory.path_join("legacy.tscn"))
	runtime.mods.stages.s00a.path = directory.path_join("legacy.tscn")
	check(runtime.change_stage("s00a").is_empty(), "Legacy overlay was rejected")
	var path := overlay.get_path_to(object)
	check(runtime.stage_override.get_node(path).global_transform.is_equal_approx(old_object), "Legacy mod placement changed")
	check(Coordinates.migrate_to_editor(overlay), "Legacy overlay was not migrated")
	check(object.global_transform.is_equal_approx(Coordinates.ROTATION * old_object), "Migration changed the authored object relative to the map")
	check(light.global_transform.is_equal_approx(Coordinates.ROTATION * old_light), "Migration rotated a nested light twice")
	check(direct_light.global_transform.is_equal_approx(Coordinates.ROTATION * old_direct_light), "Migration lost the overlay root transform")
	check(not Coordinates.migrate_to_editor(overlay), "Reopening an upright scene migrates it twice")
	check(overlay.get_meta("mgs_removals") == [rule], "Migration changed runtime removal selectors")
	save_overlay(overlay, directory.path_join("migrated.tscn"))
	runtime.mods.stages.s00a.path = directory.path_join("migrated.tscn")
	check(runtime.change_stage("s00a").is_empty(), "Migrated overlay was rejected")
	check(runtime.stage_override.get_node(path).global_transform.is_equal_approx(old_object), "Migrated object moved in game")
	check(runtime.stage_override.get_node(overlay.get_path_to(light)).global_transform.is_equal_approx(old_light), "Migrated light moved in game")
	check(runtime.stage_override.get_node("DirectLight").global_transform.is_equal_approx(old_direct_light), "Migrated root transform moved its light in game")
	overlay.free()

func run() -> void:
	var directory := "user://map-coordinates-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	var runtime := SceneView.new()
	root.add_child(runtime)
	runtime.catalog = {ASSET: {"kind": "model"}}
	runtime.mods.stages = {"s00a": {"path": "", "mod": "coordinate.test"}}
	var overlay := Node3D.new()
	Coordinates.mark_editor(overlay)
	var light := OmniLight3D.new()
	light.name = "Light"
	light.position = Vector3(2, 3, 5)
	light.shadow_enabled = true
	overlay.add_child(light)
	light.owner = overlay
	save_overlay(overlay, directory.path_join("upright.tscn"))
	runtime.mods.stages.s00a.path = directory.path_join("upright.tscn")
	check(runtime.change_stage("s00a").is_empty(), "Upright map overlay was rejected")
	var native_pose := PackedFloat32Array([1, 0, 0, 2000, 0, 1, 0, 3000, 0, 0, 1, 5000]).to_byte_array()
	var in_game: Node3D = runtime.stage_override.get_node("Light")
	check(in_game.global_position.is_equal_approx(runtime.matrix(native_pose, 0).origin), "Editor placement does not match native world position")
	check(in_game.global_basis.y.is_equal_approx(Vector3.DOWN), "Authored object orientation does not match native world up")
	check(Coordinates.validate(overlay).is_empty(), "Supported coordinate space was rejected")
	overlay.set_meta(Coordinates.META, "unknown")
	save_overlay(overlay, directory.path_join("unknown.tscn"))
	runtime.mods.stages.s00a.path = directory.path_join("unknown.tscn")
	check(not runtime.change_stage("s00a").is_empty(), "Unknown coordinate space was silently accepted")
	overlay.free()
	migration(directory, runtime)
	runtime.free()
	await process_frame
	print("MGS_MAP_COORDINATES_TEST failures=%d" % failures)
	quit(1 if failures else 0)
