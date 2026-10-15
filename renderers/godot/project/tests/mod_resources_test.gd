extends SceneTree

const Registry = preload("res://mod_registry.gd")
const Workspace = preload("res://addons/mgs_editor/mod_workspace.gd")
const Export = preload("res://addons/mgs_editor/mod_export.gd")
const Api = preload("res://visual_mod_api.gd")
class Host extends Node3D:
	var mods := Registry.new()
var failures := 0
var directory := "res://mods/.resources-test-%d" % Time.get_ticks_usec()
var repository := ProjectSettings.globalize_path("res://../../..")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func write(path: String, content: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	FileAccess.open(path, FileAccess.WRITE).store_string(content)

func python(arguments: Array) -> Dictionary:
	var output: Array = []
	var executable := repository.path_join(".venv/Scripts/python.exe" if OS.has_feature("windows") else ".venv/bin/python")
	var result := OS.execute(executable, arguments, output, true)
	check(result == 0, "Python workspace operation failed: " + "\n".join(output))
	var response = JSON.parse_string("\n".join(output))
	check(response is Dictionary and response.get("path") is String, "Missing workspace response")
	return response if response is Dictionary else {}

func fixture() -> RefCounted:
	var workspace := Workspace.new()
	workspace.root = directory.path_join("source")
	write(workspace.root.path_join("driver.gd"), 'extends Node3D\nfunc select_material(api, state):\n\tvar entry: Dictionary = api.resolve_mod_resource(self, "paint/" + state)\n\tif entry.status == "ready": entry["resource"] = load(entry.path)\n\treturn entry\n')
	write(workspace.root.path_join("map.tscn"), '[gd_scene format=3]\n[ext_resource type="Script" path="driver.gd" id="1"]\n[node name="Map" type="Node3D"]\nscript = ExtResource("1")\n')
	var material := StandardMaterial3D.new()
	material.roughness = 0.27
	check(ResourceSaver.save(material, workspace.root.path_join("paint.res")) == OK, "Cannot save binary material")
	var idle := StandardMaterial3D.new()
	idle.roughness = 0.53
	check(ResourceSaver.save(idle, workspace.root.path_join("idle.res")) == OK, "Cannot save threaded material")
	check(workspace.save({"schema":1, "id":"test.resources", "stages":{"s00a":{"scene":"map.tscn"}}}), workspace.error)
	check(workspace.register_resource("paint/alarm", workspace.root.path_join("paint.res")), workspace.error)
	check(workspace.register_resource("paint/idle", workspace.root.path_join("idle.res")), workspace.error)
	var before := FileAccess.get_file_as_bytes(workspace.root.path_join("mod.json"))
	check(not workspace.register_resource("paint/alarm", workspace.root.path_join("driver.gd")), "Duplicate resource key accepted")
	check(not workspace.register_resource("outside", "res://main.tscn"), "Outside package resource accepted")
	check(not workspace.register_resource(" ", workspace.root.path_join("driver.gd")), "Empty resource name accepted")
	check(FileAccess.get_file_as_bytes(workspace.root.path_join("mod.json")) == before, "Failed registration changed manifest")
	check(workspace.register_resource("draft", workspace.root.path_join("paint.res")), workspace.error)
	check(workspace.remove_resource("draft") and FileAccess.file_exists(workspace.root.path_join("paint.res")), "Removing resource entry deleted its file")
	return workspace

func roundtrip(workspace: RefCounted) -> Array[String]:
	var archive := directory.path_join("resources.zip")
	var error := Export.new().export_mod(workspace.root.path_join("mod.json"), archive)
	check(error.is_empty(), "Dynamic resource export failed: " + error)
	if not error.is_empty(): return []
	var imported := python([repository.path_join("tools/import_godot_mod.py"), ProjectSettings.globalize_path(archive), ProjectSettings.globalize_path(directory.path_join("opened")),
		"--godot", OS.get_executable_path(), "--project", ProjectSettings.globalize_path("res://")])
	if imported.is_empty(): return []
	var installed := str(imported.path).replace("\\", "/")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(installed.path_join("mod.json")))
	check(manifest.resources["paint/alarm"].path == "paint.tres", "Dynamic resource manifest did not follow binary alias")
	var fork := directory.path_join("fork")
	var copied := python([repository.path_join("tools/fork_godot_mod.py"), ProjectSettings.globalize_path(workspace.root), ProjectSettings.globalize_path(fork),
		ProjectSettings.globalize_path("res://"), "test.resources.fork", "Forked resources", "--godot", OS.get_executable_path()])
	if copied.is_empty(): return []
	var changed := StandardMaterial3D.new()
	changed.roughness = 0.61
	check(ResourceSaver.save(changed, fork.path_join("paint.tres")) == OK, "Cannot edit fork's material")
	check(DirAccess.rename_absolute(workspace.root, workspace.root + "-unavailable") == OK, "Cannot remove source from path lookup")
	return [installed, fork]

func resolve_checks(host: Node3D, api: Node, path: String, identity: String, roughness: float) -> Node3D:
	var packed := load(path.path_join("map.tscn")) as PackedScene
	check(packed != null, "Reopened scripted scene failed to load")
	if packed == null: return null
	var node := packed.instantiate() as Node3D
	host.add_child(node)
	var result: Dictionary = node.call("select_material", api, "alarm")
	check(result.status == "ready" and result.mod == identity, "Requester resolved a different mod")
	check(result.get("resource") is StandardMaterial3D and is_equal_approx(result.resource.roughness, roughness), "Relocated dynamic resource did not load or shared another mod's material")
	var child := Node.new()
	node.add_child(child)
	check(api.resolve_mod_resource(child, "paint/alarm").get("mod") == identity, "Child did not inherit its scene's package")
	check(api.resolve_mod_resource(result.resource, "paint/alarm").get("mod") == identity, "Resource context did not resolve its package")
	var missing: Dictionary = node.call("select_material", api, "undeclared")
	check(missing.status == "unavailable" and identity in missing.message, "Missing alias did not identify responsible mod")
	return node

func threaded_check(api: Node, node: Node3D) -> void:
	var entry: Dictionary = api.resolve_mod_resource(node, "paint/idle")
	check(not ResourceLoader.has_cached(entry.path), "Threaded check must use an uncached resource")
	check(ResourceLoader.load_threaded_request(entry.path) == OK, "Threaded mod resource request failed")
	var deadline := Time.get_ticks_msec() + 5000
	while ResourceLoader.load_threaded_get_status(entry.path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS and Time.get_ticks_msec() < deadline:
		await process_frame
	check(ResourceLoader.load_threaded_get_status(entry.path) == ResourceLoader.THREAD_LOAD_LOADED, "Threaded mod resource did not finish")
	if ResourceLoader.load_threaded_get_status(entry.path) == ResourceLoader.THREAD_LOAD_LOADED:
		var material := ResourceLoader.load_threaded_get(entry.path) as StandardMaterial3D
		check(material != null and is_equal_approx(material.roughness, 0.53), "Threaded result has wrong resource data")

func rejection_checks(path: String, api: Node, node: Node3D) -> void:
	var entry: Dictionary = api.resolve_mod_resource(node, "paint/alarm")
	var original := StandardMaterial3D.new()
	original.set_meta("mgs_retail_derived", true)
	ResourceSaver.save(original, entry.path)
	var error := Export.new().prepare(path.path_join("mod.json"))
	check("original" in error, "Named dynamic dependency bypassed provenance")
	DirAccess.remove_absolute(entry.path)
	check(api.resolve_mod_resource(node, "paint/alarm").status == "unavailable", "Deleted resource was silently resolved from cache")
	check("missing" in Registry.new().configure({}, [path.path_join("mod.json")] ), "Missing dynamic dependency was accepted at startup")
	check("missing" in Export.new().prepare(path.path_join("mod.json")), "Missing dynamic dependency was accepted at export")

func run() -> void:
	var workspace := fixture()
	var paths := roundtrip(workspace)
	if paths.size() == 2:
		var host := Host.new()
		root.add_child(host)
		check(host.mods.configure({}, [paths[0].path_join("mod.json"), paths[1].path_join("mod.json")]).is_empty(), "Registry rejected reopened/forked mods")
		var api := Api.new()
		host.add_child(api)
		check(api.start(host, []).is_empty(), "Visual API failed to start")
		var installed := resolve_checks(host, api, paths[0], "test.resources", 0.27)
		var fork := resolve_checks(host, api, paths[1], "test.resources.fork", 0.61)
		check(api.resolve_mod_resource(host, "paint/alarm").status == "unavailable", "Unowned requester borrowed a mod")
		check(api.resolve_mod_resource(null, "paint/alarm").status == "unavailable", "Null requester was not rejected")
		var extension := Node.new()
		extension.set_meta("mgs_mod_package", "test.resources")
		host.add_child(extension)
		check(api.resolve_mod_resource(extension, "paint/alarm").get("mod") == "test.resources", "Native extension association did not resolve")
		if installed != null: await threaded_check(api, installed)
		if fork != null: rejection_checks(paths[1], api, fork)
		api.stop()
		host.free()
	print("MGS_MOD_RESOURCES_TEST failures=%d" % failures)
	quit(1 if failures else 0)

func _initialize() -> void:
	run.call_deferred()
