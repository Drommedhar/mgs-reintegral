extends SceneTree

const Export = preload("res://addons/mgs_editor/mod_export.gd")
const State = preload("res://addons/mgs_editor/workspace_state.gd")
var directory := "user://binary-export-%d" % Time.get_ticks_usec()
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	FileAccess.open(path, FileAccess.WRITE).store_string(text)

func fixture() -> String:
	var source := directory.path_join("source")
	DirAccess.make_dir_recursive_absolute(source)
	var material := StandardMaterial3D.new()
	material.roughness = 0.27
	ResourceSaver.save(material, source.path_join("paint.res"))
	material.take_over_path(source.path_join("paint.res"))
	var other := StandardMaterial3D.new()
	other.roughness = 0.8
	ResourceSaver.save(other, source.path_join("paint.tres"))
	write(source.path_join("lib/tint.gdshaderinc"), "vec3 tint() { return vec3(0.2, 0.4, 0.6); }\n")
	var shader := Shader.new()
	shader.take_over_path(source.path_join("surface.res"))
	shader.code = 'shader_type spatial;\n#include "%s"\nvoid fragment() { ALBEDO = tint(); }' % source.path_join("lib/tint.gdshaderinc")
	ResourceSaver.save(shader, source.path_join("surface.res"))
	var shaded := ShaderMaterial.new()
	shaded.shader = shader
	ResourceSaver.save(shaded, source.path_join("shaded.res"))
	var mesh := MeshInstance3D.new()
	mesh.name = "CustomObject"
	mesh.mesh = BoxMesh.new()
	mesh.material_override = material
	var scene := PackedScene.new()
	scene.pack(mesh)
	ResourceSaver.save(scene, source.path_join("map.scn"))
	mesh.free()
	var script := 'extends Node\nconst MATERIAL = preload("%s")\n' % source.path_join("paint.res")
	write(source.path_join("script.gd"), script)
	write(source.path_join("wrapper.tscn"), '[gd_scene load_steps=3 format=3]\n[ext_resource type="PackedScene" path="map.scn" id="1"]\n[ext_resource type="Script" path="script.gd" id="2"]\n[node name="Root" type="Node3D"]\nscript = ExtResource("2")\n[node name="Object" parent="." instance=ExtResource("1")]\n')
	var manifest := {"schema":1,"id":"test.binary","stages":{"s00a":{"scene":"map.scn"},"s01a":{"scene":"wrapper.tscn"}},
		"materials":{"fixture":{"normal":"paint.tres"}},"appearances":{"camouflage":{"material":"shaded.res"}}}
	write(source.path_join("mod.json"), JSON.stringify(manifest))
	return source

func install(archive: String) -> String:
	var destination := directory.path_join("installed")
	var zip := ZIPReader.new()
	check(zip.open(archive) == OK, "Cannot inspect binary export")
	for name in zip.get_files():
		if name.ends_with("/"): continue
		check(not name.ends_with(".scn") and not name.ends_with(".res"), "Opaque binary resource survived export")
		var path := destination.path_join(name)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var file := FileAccess.open(path, FileAccess.WRITE)
		check(file != null, "Cannot install archive member: " + name)
		if file == null:
			zip.close()
			return ""
		file.store_buffer(zip.read_file(name))
	zip.close()
	return destination

func successful_export(source: String, archive: String) -> void:
	var scene_hash := FileAccess.get_sha256(source.path_join("map.scn"))
	var material_hash := FileAccess.get_sha256(source.path_join("paint.res"))
	var exporter := Export.new()
	check(exporter.export_mod(source.path_join("mod.json"), archive).is_empty(), "Binary export failed: " + exporter.error)
	check(FileAccess.get_sha256(source.path_join("map.scn")) == scene_hash and FileAccess.get_sha256(source.path_join("paint.res")) == material_hash, "Exporter changed binary source files")
	var installed := install(archive)
	if installed.is_empty(): return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(installed.path_join("mod.json")))
	var shaded := load(installed.path_join(data.appearances.camouflage.material)) as ShaderMaterial
	check(shaded != null and '#include "lib/tint.gdshaderinc"' in shaded.shader.code, "Embedded binary shader include was not relocated")
	check(FileAccess.file_exists(installed.path_join("lib/tint.gdshaderinc")), "Embedded shader dependency was omitted")
	check(data.stages.s00a.scene == "map.tscn", "Manifest binary reference was not relocated")
	var text := FileAccess.get_file_as_string(installed.path_join("map.tscn"))
	check("paint.res.1.tres" in text and "user://" not in text and "uid://" not in text, "Converted dependency path/UID/collision is wrong")
	var scene := ResourceLoader.load(installed.path_join("wrapper.tscn")) as PackedScene
	check(scene != null, "Installed mixed text/binary graph cannot be loaded")
	if scene != null:
		var root := scene.instantiate()
		var mesh: MeshInstance3D = root.get_node("Object")
		check(is_equal_approx(mesh.material_override.roughness, 0.27), "Converted material changed or used the colliding text resource")
		check(mesh.material_override.resource_path == installed.path_join("paint.res.1.tres"), "Installed graph retained workspace references")
		check(root.get_script().get_script_constant_map().MATERIAL == mesh.material_override, "Script and scene resolved different materials")
		root.free()
	var state := State.new()
	check(state.snapshot(source).fingerprint == state.snapshot(source).fingerprint, "Binary serialization makes unchanged workspace dirty")
	check(state.snapshot(source).fingerprint == state.snapshot(installed).fingerprint, "Portable binary normalization changes export fingerprint on reopen")

func rejection_checks(source: String, archive: String) -> void:
	var previous := FileAccess.get_file_as_bytes(archive)
	var material := StandardMaterial3D.new()
	material.set_meta("mgs_retail_derived", true)
	ResourceSaver.save(material, source.path_join("paint.res"))
	check("original geometry" in Export.new().export_mod(source.path_join("mod.json"), archive, true), "Tagged original material escaped through binary resource")
	check(FileAccess.get_file_as_bytes(archive) == previous, "Failed binary export damaged previous ZIP")
	DirAccess.remove_absolute(source.path_join("paint.res"))
	check("dependency is missing" in Export.new().export_mod(source.path_join("mod.json"), archive, true), "Missing binary dependency was not reported")
	var animation := Animation.new()
	animation.set_meta("mgs_retail_derived", true)
	var library := AnimationLibrary.new()
	library.add_animation("Original", animation)
	ResourceSaver.save(library, source.path_join("nested.res"))
	write(source.path_join("mod.json"), '{"schema":1,"id":"test.nested","postprocess":{"fixture":{"effect":"nested.res"}}}')
	check("original geometry" in Export.new().export_mod(source.path_join("mod.json"), archive, true), "Embedded original animation escaped binary inspection")
	for manifest in [{"schema":1,"id":"bad","stages":[]},{"schema":1,"id":"bad","stages":{"s00a":null}}, {"schema":1,"id":"bad","stages":{"s00a":{}}}]:
		write(source.path_join("mod.json"), JSON.stringify(manifest))
		check(not Export.new().prepare(source.path_join("mod.json")).is_empty(), "Malformed manifest crashed or passed validation")

func _initialize() -> void:
	var source := fixture()
	var archive := directory.path_join("export.zip")
	successful_export(source, archive)
	rejection_checks(source, archive)
	print("MGS_BINARY_EXPORT_TEST failures=%d" % failures)
	quit(1 if failures else 0)
