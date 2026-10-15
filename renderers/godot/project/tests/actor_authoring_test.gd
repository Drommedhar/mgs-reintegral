extends SceneTree

const DiscMap = preload("res://addons/mgs_editor/disc_map.gd")
const MapAuthoring = preload("res://addons/mgs_editor/map_authoring.gd")
const NativeAuthoring = preload("res://addons/mgs_editor/native_authoring.gd")
const Coordinates = preload("res://map_coordinates.gd")
const Export = preload("res://addons/mgs_editor/mod_export.gd")
const API = preload("res://visual_mod_api.gd")
const SceneCatalog = preload("res://addons/mgs_editor/scene_catalog.gd")
const ASSET = "mgs/integral-j/disc1/stage/s00a/6d46.k"
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func fixture(path: String) -> void:
	var model := Node3D.new()
	model.name = "OriginalFixture"
	for index in 2:
		var mesh := MeshInstance3D.new()
		mesh.name = "mesh_%03d" % index
		mesh.mesh = BoxMesh.new()
		var material := StandardMaterial3D.new()
		var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		image.fill(Color(0.3, 0.4, 0.5))
		material.albedo_texture = ImageTexture.create_from_image(image)
		material.roughness = 0.8
		mesh.mesh.material = material
		model.add_child(mesh)
		mesh.owner = model
	var scene := PackedScene.new()
	scene.pack(model)
	check(ResourceSaver.save(scene, path) == OK, "Cannot save authoring fixture")
	model.free()

func declaration(offset: int, x: int) -> Dictionary:
	return {"target":{"stage":"s00a", "script":0x6ea54, "script_sha256":"1".repeat(64), "command_offset":offset, "provider":0xec77},
		"name":0xc056, "procedure":"0123", "activation":"conditional", "status":"ready", "reason":"",
		"models":[{"asset":ASSET, "role":"body"}],
		"preview":{"position":[x, 2000, 3000], "rotation":[0, 1024, 0], "scale":[1, 1, 1], "pose":"declared"}}

func run() -> void:
	var directory := "user://actor-authoring-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	fixture(directory.path_join("original.tscn"))
	var catalog: Dictionary = JSON.parse_string(JSON.stringify({"disc":1, "assets":{ASSET:{"kind":"model", "path":"original.tscn", "parts":1, "partOwners":[0, 0]}},
		"maps":{"s00a":{"models":[], "actors":[declaration(10, 1000), declaration(50, 5000)]}}}))
	check(SceneCatalog.availability(catalog, directory, "s00a").is_empty(), "Catalog rejected prepared actor-only geometry")
	var loader := DiscMap.new()
	var reference := loader.load_map(directory, catalog, "s00a")
	check(reference != null, loader.error)
	if reference == null:
		quit(1)
		return
	check(reference.get_child_count() == 2, "Actor-only map is unavailable")
	var overlay := Node3D.new()
	Coordinates.mark_editor(overlay)
	root.add_child(overlay)
	MapAuthoring.new().attach_reference(overlay, reference)
	var session := overlay.get_node("_MapSession")
	var authoring := NativeAuthoring.new()
	authoring.attach_declarations(overlay, reference, session, directory)
	check(authoring.error.is_empty(), authoring.error)
	var bindings := overlay.get_children().filter(func(node): return node.get_meta("mgs_native_binding", false))
	check(bindings.size() == 2, "Duplicate message names merged declarations")
	var binding: Node3D = bindings[0]
	check(binding.position.is_equal_approx(Vector3(1, 2, 3)), "Actor preview placement is inverted")
	var mesh: MeshInstance3D = binding.get_node("LocalModelReference/mesh_000")
	check(binding.get_node("LocalModelReference/mesh_001").visible, "Reachable extended part is hidden")
	mesh.get_active_material(0).roughness = 0.27
	binding.get_node("LocalModelReference/mesh_001").hide()
	var lamp := OmniLight3D.new()
	lamp.name = "AttachedLamp"
	lamp.position = Vector3(0, 0.25, 0)
	mesh.add_child(lamp)
	lamp.owner = overlay
	var before := lamp.global_transform
	var copied := binding.duplicate(Node.DUPLICATE_SIGNALS | Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS) as Node3D
	copied.name = "CopiedActor"
	overlay.add_child(copied)
	for node in [copied] + copied.find_children("*", "", true, false): node.owner = overlay
	copied.get_node("LocalModelReference/mesh_000").get_active_material(0).metallic = 0.6
	session.prepare_save()
	var packed := PackedScene.new()
	packed.pack(overlay)
	var stage_path := directory.path_join("stage.tscn")
	check(ResourceSaver.save(packed, stage_path) == OK, "Actor edits did not save")
	session.finish_save()
	check(lamp.get_parent() == mesh and lamp.global_transform.is_equal_approx(before), "Save changed the open editor scene")
	check(binding.hide_original_parts == PackedInt32Array([1]), "Actor visibility edit lost")
	check(is_equal_approx(binding.get_meta("mgs_part_edits").mesh_000.surfaces[0].roughness, 0.27), "Actor material edit lost")
	check(is_equal_approx(copied.get_meta("mgs_part_edits", {}).get("mesh_000", {}).get("surfaces", {}).get(0, {}).get("metallic", 0.0), 0.6), "Copied preview material edit lost")
	var text := FileAccess.get_file_as_string(stage_path)
	check(not "LocalModelReference" in text and not "mgs_retail_derived" in text and not 'type="Image"' in text, "Original data leaked into actor edits")
	var manifest := {"schema":1, "id":"test.actor-authoring", "stages":{"s00a":{"scene":"stage.tscn"}}}
	FileAccess.open(directory.path_join("mod.json"), FileAccess.WRITE).store_string(JSON.stringify(manifest))
	check(Export.new().export_mod(directory.path_join("mod.json"), directory.path_join("mod.zip")).is_empty(), "Actor mod ZIP rejected")
	var restored := packed.instantiate()
	check(restored.get_node(NodePath(str(binding.name) + "/part_000/AttachedLamp")) != null, "Authored child lost native part parent")
	check(restored.has_node("CopiedActor/part_000/AttachedLamp"), "Copied authored child lost native part parent")
	check(restored.find_children("*", "MeshInstance3D", true, false).is_empty(), "Saved actor contains original meshes")
	var stale := binding.get_node("LocalModelReference").duplicate(Node.DUPLICATE_SIGNALS | Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS) as Node3D
	stale.scene_file_path = ""
	var restored_target: Node3D = restored.get_node(NodePath(str(binding.name)))
	var second: Node3D = restored.get_node(NodePath(str(bindings[1].name)))
	second.set_meta("mgs_part_edits", {"mesh_000": {"surfaces": {0: {"albedo_texture": mesh.get_active_material(0).albedo_texture.duplicate(true)}}}})
	restored_target.get_node("part_000/AttachedLamp").free()
	restored_target.add_child(stale)
	for node in [stale] + stale.find_children("*", "", true, false): node.owner = restored
	var contaminated := PackedScene.new()
	check(contaminated.pack(restored) == OK, "Cannot reproduce saved copied preview")
	var contaminated_path := directory.path_join("copied-preview.tscn")
	check(ResourceSaver.save(contaminated, contaminated_path) == OK, "Cannot serialize copied preview")
	restored.free()
	restored = ResourceLoader.load(contaminated_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP).instantiate()
	root.add_child(restored)
	var reopened := loader.load_map(directory, catalog, "s00a")
	MapAuthoring.new().attach_reference(restored, reopened)
	authoring.attach_declarations(restored, reopened, restored.get_node("_MapSession"), directory)
	check(authoring.error.is_empty(), authoring.error)
	check(restored.get_children().filter(func(node): return node.get_meta("mgs_native_binding", false)).size() == 3, "Reopen duplicated declaration bindings")
	var restored_binding: Node3D = restored.get_node(NodePath(str(binding.name)))
	check(not restored_binding.get_node("LocalModelReference/mesh_001").visible, "Reopen lost extended-part visibility edit")
	check(is_equal_approx(restored_binding.get_node("LocalModelReference/mesh_000").get_active_material(0).roughness, 0.27), "Reopen lost actor material edit")
	check(restored_binding.get_children().filter(func(node): return node.get_meta("mgs_reference_model", false)).size() == 1, "Reopen duplicated a copied original preview")
	var reopened_session := restored.get_node("_MapSession")
	reopened_session.prepare_save()
	check(packed.pack(restored) == OK and ResourceSaver.save(packed, stage_path) == OK, "Recovered copied preview could not save")
	reopened_session.finish_save()
	check(not "mgs_retail_derived" in FileAccess.get_file_as_string(stage_path), "Recovered copied preview still exports original data")
	check(Export.new().export_mod(directory.path_join("mod.json"), directory.path_join("recovered.zip")).is_empty(), "Recovered copied preview still blocks ZIP export")
	await process_frame
	restored.get_node("_MapSession").detach_for_reload()
	check(restored_binding.get_node_or_null("LocalModelReference") == null, "Reload retained an old actor preview")
	check(restored_binding.get_node_or_null("part_000/AttachedLamp") != null, "Reload discarded an authored attachment")
	restored.free()
	check_poses(binding)
	overlay.free()
	await process_frame
	await process_frame
	print("MGS_ACTOR_AUTHORING_TEST failures=%d" % failures)
	quit(1 if failures else 0)

func check_poses(binding: Node3D) -> void:
	binding.bound_instance = 8
	var part := binding.get_node("part_001") as Node3D
	part.position = Vector3(0, 0.5, 0)
	var poses: Array[Transform3D] = [Transform3D(Basis(Vector3.UP, 0.3).scaled(Vector3(2, 2, 2)), Vector3(4, 5, 6)),
		Transform3D(Basis(Vector3.RIGHT, 0.7), Vector3(7, 8, 9))]
	var offset := part.transform
	binding.attachment_offset.origin = Vector3(1, 0, 0)
	binding.apply_part_poses(poses)
	var body := poses[0] * Coordinates.ROTATION
	var delta: Transform3D = body * binding.attachment_offset * body.affine_inverse()
	check(part.global_transform.is_equal_approx(delta * poses[1] * Coordinates.ROTATION * offset), "Part anchor ignores independent native rotation/scale")
	poses[1].origin += Vector3(1, 2, 3)
	binding.apply_part_poses(poses)
	check(part.global_transform.is_equal_approx(delta * poses[1] * Coordinates.ROTATION * offset), "Part offset accumulated across frames")
