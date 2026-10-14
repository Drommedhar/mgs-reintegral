extends SceneTree

const State = preload("res://addons/mgs_editor/workspace_state.gd")
const Workspace = preload("res://addons/mgs_editor/mod_workspace.gd")
var failures := 0
var directory := "res://mods/.workspace-test-%d" % Time.get_ticks_usec()
var repository := ProjectSettings.globalize_path("res://../../..")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	FileAccess.open(path, FileAccess.WRITE).store_string(text)

func python(arguments: Array) -> Dictionary:
	var output: Array = []
	var executable := repository.path_join(".venv/Scripts/python.exe" if OS.has_feature("windows") else ".venv/bin/python")
	var result := OS.execute(executable, arguments, output, true)
	check(result == 0, "Python workspace action failed: " + "\n".join(output))
	var response = JSON.parse_string("\n".join(output))
	check(response is Dictionary, "Invalid workspace response: " + "\n".join(output))
	return response if response is Dictionary else {}

func fixture(binary: bool) -> RefCounted:
	var workspace := Workspace.new()
	workspace.root = directory.path_join("binary" if binary else "source")
	DirAccess.make_dir_recursive_absolute(workspace.root)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.5, 0.7)
	var material_path: String = workspace.root.path_join("paint.res" if binary else "paint.tres")
	check(ResourceSaver.save(material, material_path) == OK, "Cannot save material fixture")
	material.take_over_path(material_path)
	var mesh := MeshInstance3D.new()
	mesh.name = "AuthoredBox"
	mesh.mesh = BoxMesh.new()
	mesh.material_override = material
	var scene := PackedScene.new()
	check(scene.pack(mesh) == OK, "Cannot pack authored fixture")
	var scene_name := "map.scn" if binary else "map.tscn"
	check(ResourceSaver.save(scene, workspace.root.path_join(scene_name)) == OK, "Cannot save authored fixture")
	mesh.free()
	check(workspace.save({"schema":1, "id":"test.original", "version":"1.0", "stages":{"s00a":{"scene":scene_name}}}), workspace.error)
	return workspace

func export_history() -> void:
	var workspace := fixture(false)
	var state := State.new()
	var destination := directory.path_join("exports/current.zip")
	check(state.export_zip(workspace.root, destination).is_empty(), "First export failed: " + state.error)
	var history := state.read(workspace.root)
	check(history.export_path == ProjectSettings.globalize_path(destination), "Export destination not remembered")
	check(history.fingerprint == state.snapshot(workspace.root).fingerprint, "Fresh export is marked dirty")
	var scene_path: String = workspace.root.path_join("map.tscn")
	write(scene_path, FileAccess.get_file_as_string(scene_path).replace("AuthoredBox", "RenamedBox"))
	check(history.fingerprint != state.snapshot(workspace.root).fingerprint, "Saved scene edit was not detected")
	var data: Dictionary = workspace.manifest()
	data.version = "1.1"
	workspace.save(data)
	check(state.export_zip(workspace.root, destination).is_empty(), "Repeated export failed")
	history = state.read(workspace.root)
	check(history.version == "1.1" and history.id == "test.original", "Repeated export changed identity or lost version")
	var response := python([repository.path_join("tools/import_godot_mod.py"), ProjectSettings.globalize_path(destination), ProjectSettings.globalize_path(directory),
		"--godot", OS.get_executable_path(), "--project", ProjectSettings.globalize_path("res://")])
	check(str(response.get("path", "")).replace("\\", "/") == ProjectSettings.globalize_path(workspace.root), "Reexport created an unrelated workspace")
	var reader := ZIPReader.new()
	check(reader.open(destination) == OK, "Cannot inspect exported ZIP")
	check(reader.get_files().size() == 3, "Export contains editor history or unrelated originals")
	check("RenamedBox" in reader.read_file("map.tscn").get_string_from_utf8(), "Repeated export contains stale scene")
	check("res://mods/" not in reader.read_file("map.tscn").get_string_from_utf8(), "Export retained workspace resource paths")
	reader.close()
	var original_zip := FileAccess.get_file_as_bytes(destination)
	write(workspace.root.path_join("paint.tres"), '[gd_resource type="StandardMaterial3D" format=3]\n[resource]\nmetadata/mgs_retail_derived = true\n')
	check("original" in state.export_zip(workspace.root, destination), "Original resource was exported")
	check(FileAccess.get_file_as_bytes(destination) == original_zip, "Failed export damaged previous ZIP")
	write(destination, "external archive revision")
	check("changed outside" in state.export_zip(workspace.root, destination), "External ZIP revision was overwritten")
	check(FileAccess.get_file_as_string(destination) == "external archive revision", "External archive contents changed")

func binary_fork() -> void:
	var workspace := fixture(true)
	var source_hash := FileAccess.get_sha256(workspace.root.path_join("map.scn"))
	var destination := directory.path_join("copy")
	var response := python([repository.path_join("tools/fork_godot_mod.py"), ProjectSettings.globalize_path(workspace.root),
		ProjectSettings.globalize_path(destination), ProjectSettings.globalize_path("res://"), "test.independent", "Independent copy", "--godot", OS.get_executable_path()])
	if response.is_empty(): return
	check(FileAccess.get_sha256(workspace.root.path_join("map.scn")) == source_hash, "Save As rewrote source resource")
	var copy := Workspace.new()
	copy.root = destination
	var data := copy.manifest()
	check(data.id == "test.independent" and data.stages.s00a.scene == "map.tscn", "Save As manifest did not relocate binary scene")
	var scene := ResourceLoader.load(destination.path_join("map.tscn"), "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
	check(scene != null, "Forked binary scene cannot be opened")
	if scene != null:
		var mesh := scene.instantiate() as MeshInstance3D
		check(mesh.material_override.resource_path == destination.path_join("paint.tres"), "Copied scene still references the original workspace")
		check(mesh.material_override.albedo_color.is_equal_approx(Color(0.2, 0.5, 0.7)), "Binary conversion changed authored material")
		mesh.free()
	var state := State.new()
	check(state.read(destination).export_path.is_empty(), "Save As inherited the old export destination")
	check(state.export_zip(destination, directory.path_join("copy.zip")).is_empty(), "Converted binary workspace cannot be exported")

func clean(path: String) -> void:
	assert(path == directory or path.begins_with(directory + "/"))
	var folder := DirAccess.open(path)
	for file in folder.get_files(): DirAccess.remove_absolute(path.path_join(file))
	for child in folder.get_directories(): clean(path.path_join(child))
	DirAccess.remove_absolute(path)

func _initialize() -> void:
	export_history()
	binary_fork()
	clean(directory)
	print("MGS_WORKSPACE_ROUNDTRIP_TEST failures=%d" % failures)
	quit(1 if failures else 0)
