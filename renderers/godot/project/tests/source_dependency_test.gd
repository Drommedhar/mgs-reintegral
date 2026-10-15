extends SceneTree

const Export = preload("res://addons/mgs_editor/mod_export.gd")
var failures := 0
var directory := "user://source-dependencies-%d" % Time.get_ticks_usec()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func write(path: String, content: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	FileAccess.open(path, FileAccess.WRITE).store_string(content)

func fixture() -> void:
	write(directory.path_join("mod.json"), '{"schema":1,"id":"test.source","stages":{"s00a":{"scene":"map.tscn"}}}')
	write(directory.path_join("map.tscn"), '[gd_scene format=3]\n; [ext_resource type="Script" path="missing.gd" id="0"]\n[ext_resource type="Script" path="main.gd" id="1"]\n[node name="Map" type="Node3D"]\nscript = ExtResource("1")\n')
	write(directory.path_join("base.gd"), "extends Node3D\n")
	var source := "\n".join(PackedStringArray([
		'extends "%s/base.gd"' % directory,
		'const MATERIAL = preload ( "%s/paint.tres")' % directory,
		'# load("missing.tres")',
		'const NOTE = """load("missing.tres")',
		'preload("missing.tres")',
		'extends "missing.gd"',
		'"""',
		'const ESCAPED = "quote: \\" preload(\'missing.tres\')"',
	]))
	write(directory.path_join("main.gd"), source)
	write(directory.path_join("tint.gdshaderinc"), "vec3 tint() { return vec3(0.2, 0.3, 0.4); }\n")
	var shader := 'shader_type spatial;\n// #include "missing.gdshaderinc"\n/* #include "other-missing.gdshaderinc" */\n#include "%s/tint.gdshaderinc"\nvoid fragment() { ALBEDO = tint(); }\n' % directory
	write(directory.path_join("paint.tres"), '[gd_resource type="ShaderMaterial" format=3]\n[sub_resource type="Shader" id="1"]\ncode = "%s"\n[resource]\nshader = SubResource("1")\n' % shader.c_escape())

func check_export() -> void:
	var compiled := load(directory.path_join("main.gd")) as GDScript
	check(compiled != null and compiled.can_instantiate(), "Script fixture must compile")
	var exporter := Export.new()
	var error := exporter.prepare(directory.path_join("mod.json"))
	check(error.is_empty(), "Dependency scan rejected comments/string examples: " + error)
	if not error.is_empty(): return
	check(exporter.files.size() == 6, "Missing real dependency or collected commented references")
	var script: String = exporter.files[ProjectSettings.globalize_path(directory.path_join("main.gd"))].get_string_from_utf8()
	check('extends "base.gd"' in script and 'preload ( "paint.tres")' in script, "Actual script paths were not relocated")
	check('# load("missing.tres")' in script and 'preload("missing.tres")' in script, "Comment/docstring content was rewritten")
	var material: String = exporter.files[ProjectSettings.globalize_path(directory.path_join("paint.tres"))].get_string_from_utf8()
	check('tint.gdshaderinc' in material and not directory in material, "Embedded shader include was not relocated")
	check('missing.gdshaderinc' in material, "Commented shader include was rewritten")

func check_errors() -> void:
	write(directory.path_join("main.gd"), 'extends Node3D\nfunc sample():\n\treturn load ("paint.tres")\n')
	check("use preload()" in Export.new().prepare(directory.path_join("mod.json")), "Real literal runtime load lost its diagnostic")
	write(directory.path_join("main.gd"), 'extends "absent.gd"\n')
	check("dependency is missing" in Export.new().prepare(directory.path_join("mod.json")), "Real missing extends dependency was ignored")

func _initialize() -> void:
	fixture()
	check_export()
	check_errors()
	print("MGS_SOURCE_DEPENDENCY_TEST failures=%d" % failures)
	quit(1 if failures else 0)
