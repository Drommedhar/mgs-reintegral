extends SceneTree

const DiscMap = preload("res://addons/mgs_editor/disc_map.gd")
const MapAuthoring = preload("res://addons/mgs_editor/map_authoring.gd")
const Coordinates = preload("res://map_coordinates.gd")
const ASSET = "mgs/integral-j/disc1/stage/s00a/0001.k"
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func fixture(path: String) -> void:
	var source := Node3D.new()
	var skeleton := Skeleton3D.new()
	source.add_child(skeleton)
	skeleton.owner = source
	skeleton.add_bone("part_000")
	skeleton.set_bone_rest(0, Transform3D(Basis.IDENTITY, Vector3(1, 2, 3)))
	skeleton.reset_bone_pose(0)
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.4, 0.6))
	for index in 2:
		var mesh := MeshInstance3D.new()
		mesh.name = "mesh_%03d" % index
		mesh.position = Vector3(2, -3, -5)
		mesh.mesh = BoxMesh.new()
		var material := StandardMaterial3D.new()
		material.albedo_texture = ImageTexture.create_from_image(image)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh.material_override = material
		source.add_child(mesh)
		mesh.owner = source
	var packed := PackedScene.new()
	check(packed.pack(source) == OK and ResourceSaver.save(packed, path) == OK, "Cannot save map fixture")
	source.free()

func run() -> void:
	var directory := "user://disc-map-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	fixture(directory.path_join("map.tscn"))
	var catalog := {"maps": {"s00a": {"models": [ASSET]}}, "assets": {ASSET: {"path": "map.tscn", "parts": 1}}}
	var loader := DiscMap.new()
	var map := loader.load_map(directory, catalog, "s00a")
	check(map != null, loader.error)
	if map == null:
		quit(1)
		return
	var actor := map.get_child(0)
	var material: StandardMaterial3D = actor.get_node("mesh_000").get_active_material(0)
	check(material.albedo_texture.get_image().get_pixel(0, 0).is_equal_approx(Color(0.2, 0.4, 0.6)), "Map texture lost during preparation")
	check(material.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL, "Editor lights cannot illuminate the map")
	check(material.cull_mode == BaseMaterial3D.CULL_BACK, "Map import changed the original face culling")
	check(actor.get_child(0).get_bone_global_pose(0).is_equal_approx(Transform3D.IDENTITY), "Map did not use the native one-piece transform")
	check(not actor.get_node("mesh_001").visible, "Alternate geometry is drawn with its base part")
	var overlay := Node3D.new()
	Coordinates.mark_editor(overlay)
	root.add_child(overlay)
	var authoring := MapAuthoring.new()
	authoring.attach_reference(overlay, map)
	check(actor.get_node("mesh_000").global_position.is_equal_approx(Vector3(2, 3, 5)), "Native world height/depth were inverted in the editor")
	check(not actor.get_node("mesh_001").visible, "Attaching the reference enabled alternate geometry")
	var rule := authoring.removal_for(actor.get_node("mesh_000"), overlay, true)
	check(rule.asset == ASSET and rule.part == 0 and rule.anchor.is_equal_approx(Vector3.ZERO), "Disc map removal does not match runtime identity/position")
	var saved := PackedScene.new()
	check(actor.owner == overlay and actor.get_node("mesh_000").owner == overlay, "Original nodes are absent from the Scene tree")
	overlay.propagate_notification(Node.NOTIFICATION_EDITOR_PRE_SAVE)
	overlay.get_node("_MapSession").prepare_save()
	check(saved.pack(overlay) == OK, "Cannot pack map overlay")
	overlay.propagate_notification(Node.NOTIFICATION_EDITOR_POST_SAVE)
	overlay.get_node("_MapSession").finish_save()
	check(actor.owner == overlay, "Saving removed original nodes from the Scene tree")
	var restored := saved.instantiate()
	check(restored.find_children("*", "MeshInstance3D", true, false).is_empty() and not restored.has_node("LocalMapReference"), "Original disc geometry leaked into the mod scene")
	check(restored.has_node("EventLightTemplates/WeaponSpot"), "Authored light templates were stripped from the mod")
	check(restored.get_meta(Coordinates.META) == Coordinates.EDITOR, "Map coordinate space was lost when saving")
	check(loader.load_map(directory, catalog, "absent") == null and not loader.error.is_empty(), "Missing map did not report a preparation error")
	restored.free()
	overlay.free()
	print("MGS_DISC_MAP_TEST failures=%d" % failures)
	quit(1 if failures else 0)
