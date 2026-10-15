extends SceneTree

const Authoring = preload("res://addons/mgs_editor/native_authoring.gd")
const Session = preload("res://addons/mgs_editor/map_session.gd")
const Export = preload("res://addons/mgs_editor/mod_export.gd")
const Actors = preload("res://native_actors.gd")
const API = preload("res://visual_mod_api.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func own(node: Node, scene: Node) -> void:
	for child in node.get_children():
		child.owner = scene
		own(child, scene)

func packet() -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(136)
	var fields := [1,1,1,1,3,8,5,0xb15b,1,0x2abc,20,3,0x6ea54,5981]
	for i in fields.size(): bytes.encode_u32(i*4, fields[i])
	for i in 4: bytes[56+i] = "s00a".unicode_at(i)
	var digest: PackedByteArray = Authoring.TARGET.script_sha256.hex_decode()
	for i in 32: bytes[64+i] = digest[i]
	bytes.encode_float(96, 1)
	bytes.encode_float(100, 4)
	bytes.encode_float(104, -28.8)
	bytes.encode_s32(108, 225)
	bytes.encode_s32(112, 450)
	bytes.encode_u32(116, 1)
	for i in 16: bytes[120+i] = 0x5a
	return bytes

func run() -> void:
	var directory := "user://native-binding-%d" % Time.get_ticks_usec()
	var asset_root := "res://../../../.local/godot-content"
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(asset_root.path_join("catalog.json")))
	var authoring := Authoring.new()
	var overlay := Node3D.new()
	root.add_child(overlay)
	var binding := authoring.create_dock_binding(directory, catalog.assets)
	check(binding != null, authoring.error)
	if binding == null:
		quit(1)
		return
	overlay.add_child(binding)
	own(overlay, overlay)
	var session := Session.new()
	overlay.add_child(session)
	session.overlay = overlay
	authoring.attach_previews(overlay, catalog.assets, asset_root, session)
	check(authoring.error.is_empty() and session.native_previews.size() == 5, "Original part previews missing")
	var part: Node3D = binding.get_child(2)
	part.name = "RenamedRailing"
	var original: Node3D = part.get_child(0)
	original.hide()
	var custom := MeshInstance3D.new()
	custom.name = "CustomRailing"
	custom.mesh = BoxMesh.new()
	part.add_child(custom)
	custom.owner = overlay
	var lamp := OmniLight3D.new()
	lamp.name = "AuthoredLamp"
	lamp.position = Vector3(0, 0.5, 0)
	original.add_child(lamp)
	lamp.owner = overlay
	var before := lamp.global_transform
	authoring.attach_previews(overlay, catalog.assets, asset_root, session)
	check(is_instance_valid(original) and lamp.get_parent() == original and session.native_previews.size() == 5, "Refreshing previews replaced authored children")
	var deleted: Node = binding.get_child(4).get_child(0)
	deleted.free()
	var scene_path := directory.path_join("stage.tscn")
	session.prepare_save()
	var packed := PackedScene.new()
	check(packed.pack(overlay) == OK and ResourceSaver.save(packed, scene_path) == OK, "Cannot save binding scene")
	session.finish_save()
	check(lamp.get_parent() == original and lamp.global_transform.is_equal_approx(before), "Save changed live editor hierarchy")
	check(binding.hide_original_parts == PackedInt32Array([2,4]), "Visibility/deletion edits did not suppress original parts")
	var scene_text := FileAccess.get_file_as_string(scene_path)
	check(not "Original_mesh" in scene_text and not "mgs_retail_derived" in scene_text, "Original preview was saved")
	var manifest := {"schema":1,"id":"test.native-binding","stages":{"s00a":{"scene":"stage.tscn"}}}
	FileAccess.open(directory.path_join("mod.json"), FileAccess.WRITE).store_string(JSON.stringify(manifest))
	var archive := directory.path_join("mod.zip")
	check(Export.new().export_mod(directory.path_join("mod.json"), archive).is_empty(), "Binding export failed")
	var zip := ZIPReader.new()
	check(zip.open(archive) == OK, "Cannot read exported binding ZIP")
	var files := Array(zip.get_files()).filter(func(path): return not str(path).ends_with("/"))
	check(files.size() == 4, "Binding ZIP leaked original dependencies")
	var installed := directory.path_join("installed")
	for name in files:
		var path := installed.path_join(name)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		FileAccess.open(path, FileAccess.WRITE).store_buffer(zip.read_file(name))
	zip.close()
	overlay.free()
	var api := API.new()
	root.add_child(api)
	var actors := Actors.new()
	root.add_child(actors)
	api.native_actors = actors
	actors.session_id = PackedByteArray()
	actors.session_id.resize(16)
	actors.session_id.fill(0x5a)
	api.publish_native_context({"epoch":3})
	var bytes := packet()
	check(actors.apply(bytes, {"epoch":3}).is_empty(), "Native fixture rejected")
	var restored := load(installed.path_join("stage.tscn")).instantiate() as Node3D
	restored.transform = Transform3D(Basis(Vector3.UP, PI/3).scaled(Vector3(2,3,4)), Vector3(10,5,-2))
	root.add_child(restored)
	var attached := restored.get_child(0)
	check(attached.bound_instance == 8 and attached.global_transform.is_equal_approx(actors.actors[1].body.global_transform), "Reopened binding did not attach to current native pose")
	attached.target = Authoring.TARGET.duplicate(true)
	attached.target.command_offset = 100
	attached.alternate_targets.append(Authoring.TARGET.duplicate(true))
	attached.refresh()
	check(attached.bound_instance == 8, "Explicit declaration alternative did not resolve")
	attached.alternate_targets.append(Authoring.TARGET.duplicate(true))
	attached.refresh()
	check(attached.bound_instance == 0 and "Multiple" in attached.binding_status, "Ambiguous alternatives selected an arbitrary actor")
	attached.alternate_targets.clear()
	attached.target = Authoring.TARGET.duplicate(true)
	attached.refresh()
	var indicator := MeshInstance3D.new()
	indicator.material_override = StandardMaterial3D.new()
	indicator.set_script(preload("res://examples/native_elevator/indicator.gd"))
	attached.add_child(indicator)
	check(indicator.material_override.emission.is_equal_approx(Color(1.0, 0.35, 0.03)), "Late indicator did not initialize from current native state")
	check(attached.has_node("RenamedRailing/AuthoredLamp"), "Nested authored child lost its moving part parent")
	var entry := {"node":Node3D.new(), "meshes":[], "metadata_meshes":[]}
	for i in 5:
		var mesh := MeshInstance3D.new()
		mesh.name = "mesh_%03d" % i
		entry.node.add_child(mesh)
		entry.meshes.append(mesh)
	api.apply_actor_removals(entry, 99)
	check(entry.meshes[2].visible, "Suppressed another actor's mesh")
	api.apply_actor_removals(entry, 8)
	check(not entry.meshes[2].visible and entry.meshes[1].visible and attached.get_node("RenamedRailing/CustomRailing").visible, "Part suppression hid custom or unrelated meshes")
	bytes.encode_u32(4, 2)
	bytes.encode_float(100, 2)
	check(actors.apply(bytes, {"epoch":3}).is_empty(), "Native movement fixture rejected")
	api.native_actors_updated.emit()
	check(attached.global_position.is_equal_approx(Vector3(1,-2,28.8)), "Replacement did not follow native movement")
	attached.hide()
	api.native_actors_updated.emit()
	check(not attached.visible and attached.native_visible, "Native refresh overwrote authored root visibility")
	var hidden_scene := PackedScene.new()
	check(hidden_scene.pack(restored) == OK, "Cannot save hidden authored binding")
	var hidden_copy := hidden_scene.instantiate()
	check(not hidden_copy.get_child(0).visible, "Saving lost authored binding visibility")
	hidden_copy.free()
	attached.show()
	api.publish_native_context({"epoch":4})
	check(attached.visible and not attached.native_visible and attached.bound_instance == 0, "Reload changed authored visibility or retained native availability")
	api.publish_native_context({"epoch":3})
	check(attached.native_visible and attached.bound_instance == 8, "Returning to a current actor did not restore its native mask")
	root.remove_child(restored)
	api.remove_from_group("mgs_visual_api_v1")
	root.add_child(restored)
	check(attached.visible and not attached.native_visible and attached.bound_instance == 0, "Detached binding retained stale availability without a native session")
	entry.node.free()
	restored.free()
	check(api.actor_bindings.is_empty(), "Retired overlay left registered bindings")
	api.free()
	actors.free()
	print("MGS_NATIVE_BINDING_WORKFLOW_TEST failures=%d" % failures)
	quit(1 if failures else 0)
