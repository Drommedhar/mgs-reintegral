extends SceneTree

const SceneView = preload("res://scene_view.gd")
const ASSET = "mgs/integral-j/disc1/stage/init/0001.k"
var scene := SceneView.new()
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func snapshot() -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(68)
	data.encode_float(8, 1.0)
	data.encode_float(28, 1.0)
	data.encode_float(48, 1.0)
	data.encode_float(56, 320.0)
	data.encode_u32(60, 1)
	data.encode_float(64, 1.0)
	var instance := PackedByteArray()
	instance.resize(32)
	instance.encode_u32(0, 1)
	instance.encode_u32(4, 1)
	for index in 4:
		instance[8 + index] = "init".unicode_at(index)
	instance.encode_u32(20, 1)
	instance.encode_u32(24, 1)
	instance.encode_u32(28, 4)
	data.append_array(instance)
	data.append_array(PackedFloat32Array([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 2000]).to_byte_array())
	data.append_array(PackedInt32Array([3]).to_byte_array())
	for _corner in 4:
		data.append_array(PackedByteArray([128, 64, 32, 255]))
	for _corner in 4:
		data.append_array(PackedFloat32Array([0.25, 0.5, 6000, 0]).to_byte_array())
	data.append_array(PackedInt32Array([0, 0]).to_byte_array())
	return data

func fixture() -> void:
	root.add_child(scene)
	scene.add_child(scene.camera)
	var directory := "user://mgs-scene-snapshot-test"
	DirAccess.make_dir_recursive_absolute(directory)
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	check(image.save_png(directory.path_join("0002.png")) == OK, "Cannot write fixture texture")
	check(image.save_png(directory.path_join("0002.stp.png")) == OK, "Cannot write fixture mask")
	scene.catalog = {ASSET: {"kind": "model", "colorCount": 4},
		"mgs/integral-j/disc1/stage/init/0002.p": {"kind": "texture", "path": "0002.png"}}
	scene.materials.initialize(scene.catalog, scene.mods, directory)
	var model := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.name = "mesh_000"
	mesh.mesh = ArrayMesh.new()
	mesh.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, QuadMesh.new().get_mesh_arrays())
	var material := StandardMaterial3D.new()
	material.resource_name = "0002"
	mesh.mesh.surface_set_material(0, material)
	var empty := StandardMaterial3D.new()
	empty.resource_name = "0000"
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.ZERO, Vector3.UP])
	mesh.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.mesh.surface_set_material(1, empty)
	model.add_child(mesh)
	scene.templates[ASSET] = model

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	fixture()
	var data := snapshot()
	check(scene.update_scene(data).is_empty(), "Valid v9 scene rejected")
	if scene.instances.has(1):
		var entry: Dictionary = scene.instances[1]
		check(entry.asset == ASSET, "Definition-stage identity changed")
		check(entry.packet_data.decode_float(0) == 0.25 and entry.packet_data.decode_float(8) == 6000, "Live UV/order palette was not decoded")
		check(entry.colors[3] == 255, "Face visibility was not decoded")
		check(entry.metadata_meshes.size() == 1, "Reference mesh has no metadata counterpart")
		check(entry.meshes[0].gi_mode == GeometryInstance3D.GI_MODE_DISABLED, "Actor contributed static GI")
		check(entry.metadata_meshes[0].gi_mode == GeometryInstance3D.GI_MODE_DISABLED, "Metadata duplicate contributed GI")
		scene.map_definitions[""] = {"models": [ASSET]}
		check(scene.update_scene(data).is_empty() and entry.meshes[0].gi_mode == GeometryInstance3D.GI_MODE_STATIC, "Declared map did not contribute GI")
		check(entry.meshes[0].get_active_material(1) == scene.materials.empty_surface and
			entry.metadata_meshes[0].get_active_material(1) == scene.materials.empty_surface,
			"Degenerate textureless surface disabled a textured part or leaked metadata")
		data.encode_u32(148, 7)
		check(scene.update_scene(data).is_empty(), "Transparent original part rejected")
		check(entry.meshes[0].gi_mode == GeometryInstance3D.GI_MODE_DISABLED, "Transparent water became a static GI blocker")
		var transparent := entry.meshes[0].get_active_material(0) as ShaderMaterial
		check("blend_premul_alpha" in transparent.shader.code, "Transparent part kept its opaque material")
		data.encode_u32(148, 2)
		check(scene.update_scene(data).is_empty(), "Offscreen shadow caster rejected")
		check(entry.meshes[0].visible and entry.meshes[0].cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY,
			"Camera culling removed a shadow caster")
		check(not entry.metadata_meshes[0].visible and scene.visible_mesh_parts == 0, "Shadow-only part leaked into color/metadata")
		entry.shadow_modes[0] = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		check(scene.update_scene(data).is_empty() and not entry.meshes[0].visible, "Authored Cast Shadow Off was overridden")
		entry.shadow_modes[0] = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		scene.removals.matches[1] = [0]
		check(scene.update_scene(data).is_empty() and not entry.meshes[0].visible, "Visual removal retained a shadow caster")
		scene.removals.matches.clear()
		data.encode_u32(84, 0x80)
		check(scene.update_scene(data).is_empty() and not entry.node.visible, "Game-hidden actor retained a shadow")
		data.encode_u32(84, 0)
		data.encode_float(168, 0.75)
		data.encode_u32(148, 0)
		for index in 4:
			data[index] = "s01a".unicode_at(index)
		check(scene.update_scene(data).is_empty(), "Stage transition rejected")
		check(scene.instances[1].node == entry.node and entry.asset == ASSET, "Resident asset was replaced across stages")
		check(entry.packet_data.decode_float(0) == 0.75, "Live UV change was frozen")
		check(not entry.meshes[0].visible and not entry.metadata_meshes[0].visible, "Compatibility ownership did not hide both meshes")
		var changed_asset := ASSET.replace("0001.k", "0003.k")
		scene.catalog[changed_asset] = scene.catalog[ASSET].duplicate()
		scene.templates[changed_asset] = scene.templates[ASSET].duplicate()
		var changed := data.duplicate()
		changed.encode_u32(72, 3)
		scene.removals.matches[1] = [-1]
		check(scene.update_scene(changed).is_empty(), "Live model change rejected")
		check(scene.instances[1].asset == changed_asset and scene.instances[1].node != entry.node, "Lifetime ID retained stale model resource")
		check(not entry.node.visible, "Retired model remained visible until deferred deletion")
		check(not scene.instances[1].node.visible, "Hidden original reappeared after a native model swap")
		scene.removals.matches.clear()
		check(scene.update_scene(data).is_empty(), "Original model could not be restored")
		var hidden: Dictionary = scene.instances[1]
		hidden.meshes[0].mesh.surface_get_material(0).resource_name = "6173"
		hidden.material_stages.clear()
		check(scene.update_scene(data).is_empty(), "Compatibility-owned material required an unused prepared texture")
		var visible := data.duplicate()
		visible.encode_u32(148, 1)
		check(not scene.update_scene(visible).is_empty(), "Missing visible material was silently accepted")
		hidden.meshes[0].mesh.surface_get_material(0).resource_name = "0002"
		check(scene.update_scene(data).is_empty(), "Compatibility ownership could not be restored")
	check(not scene.update_scene(data.slice(0, data.size() - 1)).is_empty(), "Truncated packet palette accepted")
	var bad_flags := data.duplicate()
	bad_flags.encode_u32(148, 8)
	check(not scene.update_scene(bad_flags).is_empty(), "Unknown part flags accepted")
	var duplicate := data.duplicate()
	duplicate.encode_u32(60, 2)
	duplicate.append_array(data.slice(68))
	check(not scene.update_scene(duplicate).is_empty(), "Duplicate lifetime ID accepted")
	var bad_count := data.duplicate()
	bad_count.encode_u32(96, 0)
	check(not scene.update_scene(bad_count).is_empty(), "Mismatched color count accepted")
	var generated := data.duplicate()
	generated.encode_u32(72, 0x80000001)
	check(not scene.update_scene(generated).is_empty(), "Generated model accepted retail palette")
	var preview_data := data.duplicate()
	for index in 8: preview_data[index] = 0
	for index in 6: preview_data[index] = "testv4".unicode_at(index)
	check(scene.update_scene(preview_data).is_empty(), "Preview fixture scene rejected")
	check(scene.export_snapshot().is_empty(), "Scene preview export failed")
	var packed := load("res://.generated/previews/testv4.tscn") as PackedScene
	check(packed != null, "Exported preview cannot be loaded")
	if packed != null:
		var preview := packed.instantiate()
		check(preview.find_children("metadata_*", "MeshInstance3D", true, false).is_empty(), "Internal metadata meshes leaked into editor preview")
		check(preview.get_node("ReferenceCamera").compositor == null, "Runtime compositor leaked into editor preview")
		var actors := preview.get_children().filter(func(node): return node.get_meta("mgs_asset_id", "") == ASSET)
		check(actors.size() == 1, "Editor preview lost stable asset identity")
		preview.free()
	var empty := data.slice(0, 68)
	empty.encode_u32(60, 0)
	empty.append_array(PackedInt32Array([0, 0]).to_byte_array())
	check(scene.update_scene(empty).is_empty() and scene.instances.is_empty(), "Absent instance was retained")
	print("MGS_SCENE_SNAPSHOT_TEST failures=%d" % failures)
	scene.free()
	quit(1 if failures else 0)
