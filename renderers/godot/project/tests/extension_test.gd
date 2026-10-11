extends SceneTree

const SceneView = preload("res://scene_view.gd")
const ModExport = preload("res://addons/mgs_editor/mod_export.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func install_package() -> String:
	var directory := "user://native-mod-%d" % Time.get_ticks_usec()
	var archive := directory.path_join("native.zip")
	var error := ModExport.new().export_mod("res://../../../build/godot-sdk-x64/mod/mod.json", archive)
	check(error.is_empty(), error)
	if not error.is_empty(): return ""
	var reader := ZIPReader.new()
	if reader.open(archive) != OK:
		check(false, "Cannot open packaged native mod")
		return ""
	var installed := directory.path_join("installed")
	for name in reader.get_files():
		if name.ends_with("/"): continue
		var target := installed.path_join(name)
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		FileAccess.open(target, FileAccess.WRITE).store_buffer(reader.read_file(name))
	reader.close()
	return installed.path_join("example.gdextension")

func run() -> void:
	var extension_path := install_package()
	if extension_path.is_empty():
		quit(1)
		return
	var scene := SceneView.new()
	root.add_child(scene)
	scene.add_child(scene.mod_api)
	var definitions: Array[Dictionary] = [{"path": extension_path,
		"class": "MgsExampleMod", "mod": "test.native"}]
	var error: String = scene.mod_api.start(scene, definitions)
	check(error.is_empty(), error)
	if error.is_empty():
		var extension: Node3D = scene.mod_api.extensions[0]
		var light := extension.get_node("MovingLight") as OmniLight3D
		check(light != null and light.shadow_enabled, "Compiled extension did not create a shadow light")
		scene.scene_stage = "s00a"
		scene.mod_api.publish_snapshot()
		check(extension.visible and light.position.is_equal_approx(Vector3(-6, 3, 5)), "Native stage callback did not place its light")
		var before := light.position
		await process_frame
		await process_frame
		check(light.position.distance_to(before) > 0, "Native extension did not animate its light")
		scene.scene_stage = "s01a"
		scene.mod_api.publish_snapshot()
		check(light.position.is_equal_approx(Vector3(-4, 4, -20)), "Stage change did not relocate native light")
		scene.scene_stage = "title"
		scene.mod_api.publish_snapshot()
		check(not extension.visible, "Extension visuals leaked into unsupported stage")
	scene.mod_api.stop()
	check(scene.mod_api.get_child_count() == 0, "Native extension nodes survived shutdown")
	definitions[0].class = "Node3D"
	check(not scene.mod_api.start(scene, definitions).is_empty(), "Missing native lifecycle hooks were accepted")
	scene.free()
	print("MGS_EXTENSION_TEST failures=%d" % failures)
	quit(1 if failures else 0)
