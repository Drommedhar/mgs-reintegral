extends "res://tests/scene_snapshot_test.gd"

const Appearance = preload("res://object_appearance.gd")
const Authoring = preload("res://addons/mgs_editor/appearance_authoring.gd")
const Workspace = preload("res://addons/mgs_editor/mod_workspace.gd")
const Registry = preload("res://mod_registry.gd")
const Export = preload("res://addons/mgs_editor/mod_export.gd")

func run() -> void:
	fixture()
	var normal := snapshot()
	check(scene.update_scene(normal).is_empty(), "Normal scene rejected")
	var entry: Dictionary = scene.instances[1]
	var original: Material = entry.meshes[0].get_active_material(0)
	scene.object_appearance = true
	var data := normal.slice(0, 100)
	data.append_array(PackedInt32Array([1, 0, 0x60a080]).to_byte_array())
	data.append_array(normal.slice(100))
	data.encode_float(104, 0.25)
	check(scene.update_scene(data).is_empty(), "Camouflage snapshot rejected")
	var material: ShaderMaterial = entry.meshes[0].get_active_material(0)
	check(material.shader == Appearance.SHADER, "Camouflage kept packet shader")
	check(material.get_shader_parameter("camouflage_amount") == 0.25, "Transition amount lost")
	check(material.get_shader_parameter("native_tint") == Vector3(1, 1.25, 0.75), "Native tint lost")
	check(not entry.metadata_meshes[0].visible, "Camouflage leaked legacy packet metadata")
	check(entry.meshes[0].cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Cloaked character casts opaque shadow")
	check(entry.meshes[0].get_active_material(1) == scene.materials.empty_surface, "Empty surface became visible")
	data.encode_float(104, 1.0)
	check(scene.update_scene(data).is_empty(), "Transition update rejected")
	check(entry.meshes[0].get_active_material(0) == material and material.get_shader_parameter("camouflage_amount") == 1.0, "Transition recreated material or froze")
	scene.mod_api.scene = scene
	var exposed: Dictionary = scene.mod_api.get_instances()[0].appearance
	check(exposed.amount == 1.0 and exposed.kind == 1, "Mod API lost native appearance")
	exposed.kind = 0
	check(entry.appearance.kind == 1, "Mod API exposed mutable native appearance")
	for sample in [[100, 2], [108, 0xff808080]]:
		var invalid := data.duplicate()
		invalid.encode_u32(sample[0], sample[1])
		check(not scene.update_scene(invalid).is_empty(), "Invalid appearance enum/tint accepted")
	for amount in [-0.1, 1.1, NAN, INF]:
		var invalid := data.duplicate()
		invalid.encode_float(104, amount)
		check(not scene.update_scene(invalid).is_empty(), "Invalid appearance amount accepted")
	data.encode_u32(100, 0)
	check(scene.update_scene(data).is_empty(), "Appearance clear rejected")
	check(entry.meshes[0].get_active_material(0) == original, "Clearing did not restore original material")
	check(entry.metadata_meshes[0].visible and entry.meshes[0].cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "Clearing did not restore metadata/shadow policy")
	scene.remove_instance(1)
	data.encode_u32(100, 1)
	data.encode_u32(160, 0)
	check(scene.update_scene(data).is_empty(), "Hidden camouflaged spawn rejected")
	data.encode_u32(160, 3)
	check(scene.update_scene(data).is_empty(), "Camouflaged part reveal rejected")
	check(scene.instances[1].meshes[0].get_active_material(0).shader == Appearance.SHADER, "Newly visible part lost camouflage")
	check_custom_mesh()
	check_package()
	print("MGS_OBJECT_APPEARANCE_TEST failures=%d" % failures)
	quit(1 if failures else 0)

func check_custom_mesh() -> void:
	var appearance := Appearance.new()
	appearance.initialize({})
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	var authored := StandardMaterial3D.new()
	authored.albedo_color = Color.RED
	mesh.material_override = authored
	var entry := {"meshes": [mesh], "material_stages": {}, "appearance": {"kind": 1, "amount": 1.0, "tint": Vector3.ONE}}
	appearance.apply(entry, "active", null)
	check(mesh.material_override != authored and mesh.material_override.get_shader_parameter("base_color") == Color.RED, "Custom material was mutated or lost tint")
	appearance.prepare(entry, "")
	check(mesh.material_override == authored and not entry.has("appearance_cache"), "Authored override was not restored")
	mesh.free()

func check_package() -> void:
	var workspace := Workspace.new()
	workspace.root = "user://camouflage-mod-%d" % Time.get_ticks_usec()
	var authoring := Authoring.new()
	var material := authoring.open_material(workspace)
	check(material != null, "Authoring failed: " + authoring.error)
	if material == null: return
	material.set_shader_parameter("distortion", 0.025)
	check(ResourceSaver.save(material, material.resource_path) == OK, "Cannot save authored camouflage")
	check(authoring.open_material(workspace) == material, "Reopening overwrote edits")
	var exporter := Export.new()
	var archive: String = workspace.root.path_join("camouflage.zip")
	check(exporter.export_mod(workspace.root.path_join("mod.json"), archive).is_empty(), "Cannot export camouflage: " + exporter.error)
	var zip := ZIPReader.new()
	check(zip.open(archive) == OK, "Cannot read exported ZIP")
	var files := Array(zip.get_files()).filter(func(path): return not path.ends_with("/"))
	check(files.size() == 3, "Camouflage ZIP contains unexpected dependencies")
	var installed: String = workspace.root.path_join("installed")
	for file in files:
		var path := installed.path_join(str(file))
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		FileAccess.open(path, FileAccess.WRITE).store_buffer(zip.read_file(file))
	zip.close()
	var registry := Registry.new()
	check(registry.configure({}, [installed.path_join("mod.json")]).is_empty(), "Relocated ZIP manifest rejected")
	var appearance := Appearance.new()
	check(appearance.initialize(registry.appearances).is_empty(), "Relocated appearance failed to load")
	check(is_equal_approx(appearance.template.get_shader_parameter("distortion"), 0.025), "ZIP reopening lost material edit")
	var reopened := Workspace.new()
	reopened.root = installed
	check(Authoring.new().open_material(reopened) != null, "Imported appearance cannot be edited")
	var manifest: Dictionary = workspace.manifest()
	manifest.root = workspace.root
	manifest.appearances.camouflage.material = "../outside.tres"
	check(not Registry.new().register_manifest({}, manifest).is_empty(), "External appearance path accepted")
	var invalid := ShaderMaterial.new()
	invalid.shader = Shader.new()
	invalid.shader.code = "shader_type spatial;"
	var path: String = workspace.root.path_join("invalid.tres")
	ResourceSaver.save(invalid, path)
	check("native input" in Appearance.new().initialize({"camouflage": {"material": path}}), "Shader without native inputs accepted")
