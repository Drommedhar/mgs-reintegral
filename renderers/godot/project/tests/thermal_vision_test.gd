extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var workspace := preload("res://addons/mgs_editor/mod_workspace.gd").new()
	workspace.root = "user://thermal-vision-%d" % Time.get_ticks_usec()
	var authoring := preload("res://addons/mgs_editor/night_vision_authoring.gd").new()
	var effect := authoring.open_effect(workspace, "thermal_vision")
	check(effect != null, "Thermal authoring failed: " + authoring.error)
	if effect == null:
		quit(1)
		return
	effect.set("hot_tint", Color(0.2, 0.4, 1.0))
	check(ResourceSaver.save(effect, effect.resource_path) == OK, "Cannot save thermal edit")
	check(authoring.open_effect(workspace, "thermal_vision") == effect, "Reopening reset the thermal edit")
	var exporter := preload("res://addons/mgs_editor/mod_export.gd").new()
	var archive: String = workspace.root.path_join("thermal.zip")
	check(exporter.export_mod(workspace.root.path_join("mod.json"), archive).is_empty(), "Thermal export failed: " + exporter.error)
	var zip := ZIPReader.new()
	check(zip.open(archive) == OK, "Cannot reopen thermal ZIP")
	var files := Array(zip.get_files()).filter(func(path): return not path.ends_with("/"))
	check(files.size() == 4, "Thermal export must include manifest, resource, derived script and base script")
	var installed: String = workspace.root.path_join("installed")
	for file in files:
		var path: String = installed.path_join(file)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		FileAccess.open(path, FileAccess.WRITE).store_buffer(zip.read_file(file))
	zip.close()
	var registry := preload("res://mod_registry.gd").new()
	check(registry.configure({}, [installed.path_join("mod.json")]).is_empty(), "Reopened thermal package rejected")
	var vision := preload("res://vision_effects.gd").new()
	check(vision.initialize(registry.postprocess, func(message): check(false, message)).is_empty(), "Cannot initialize reopened thermal effect")
	check(vision.thermal_world.get("hot_tint") == Color(0.2, 0.4, 1.0), "Thermal color edit lost")
	vision.update({"vision_mode": 2})
	check(not vision.thermal_world.enabled, "Thermal filter activated without negotiated ownership")
	vision.thermal_enabled = true
	vision.update({"vision_mode": 2})
	check(vision.thermal_world.enabled and vision.thermal_background.enabled and not vision.world.enabled, "Thermal ownership did not select the proper effects")
	vision.update({"vision_mode": 1})
	check(not vision.thermal_world.enabled and vision.world.enabled, "Thermal-to-night switching failed")
	vision.update({"vision_mode": 0})
	check(not vision.world.enabled and not vision.thermal_background.enabled, "Vision effect remained active on removal")
	var sources := preload("res://thermal_sources.gd").new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = QuadMesh.new()
	check(not sources.register(mesh, 1.0).is_empty(), "Detached thermal source accepted")
	root.add_child(mesh)
	var empty := ShaderMaterial.new()
	check(not sources.register(mesh, NAN).is_empty(), "Nonfinite heat accepted")
	check(sources.register(mesh, 0.4).is_empty(), "Valid authored heat rejected")
	sources.synchronize({}, true, empty)
	check(sources.copies.size() == 1, "Authored heat source not created")
	var parent := Node3D.new()
	parent.position = Vector3(3, 4, 5)
	root.add_child(parent)
	mesh.reparent(parent, false)
	sources.synchronize({}, true, empty)
	check(sources.copies[mesh].global_transform.is_equal_approx(mesh.global_transform), "Reparented heat source used its previous coordinate frame")
	var geometry := mesh.mesh
	mesh.mesh = null
	sources.synchronize({}, true, empty)
	check(sources.copies.is_empty(), "Mesh without geometry retained a heat surface")
	mesh.mesh = geometry
	sources.synchronize({}, true, empty)
	check(sources.copies.has(mesh), "Restoring geometry lost authored heat registration")
	mesh.layers = 2
	sources.synchronize({}, true, empty, 1)
	check(not sources.copies[mesh].visible, "Camera-excluded geometry remained visible in thermal mode")
	mesh.layers = 1
	sources.unregister(mesh)
	sources.synchronize({1: {"thermal": true, "meshes": [mesh]}}, true, empty)
	mesh.hide()
	sources.synchronize({1: {"thermal": true, "meshes": [mesh]}}, true, empty)
	check(not sources.copies[mesh].visible, "Hidden native part still produced heat")
	mesh.free()
	sources.synchronize({}, true, empty)
	check(sources.copies.is_empty(), "Retired source left a heat copy")
	parent.free()
	RenderingServer.call_on_render_thread(vision.release)
	await process_frame
	print("MGS_THERMAL_VISION_TEST failures=%d" % failures)
	quit(1 if failures else 0)
