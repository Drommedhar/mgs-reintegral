extends SceneTree

const Vision = preload("res://vision_effects.gd")
const Authoring = preload("res://addons/mgs_editor/night_vision_authoring.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var workspace := preload("res://addons/mgs_editor/mod_workspace.gd").new()
	workspace.root = "user://night-vision-%d" % Time.get_ticks_usec()
	var authoring := Authoring.new()
	var effect := authoring.open_effect(workspace)
	check(effect != null, "Night vision authoring failed: " + authoring.error)
	if effect == null:
		quit(1)
		return
	effect.set("gain", 4.5)
	effect.set("tint", Color(0.1, 0.8, 0.25))
	check(ResourceSaver.save(effect, effect.resource_path) == OK, "Cannot save night vision edits")
	check(authoring.open_effect(workspace) == effect, "Reopening overwrote night vision edits")
	var archive: String = workspace.root.path_join("vision.zip")
	var exporter := preload("res://addons/mgs_editor/mod_export.gd").new()
	check(exporter.export_mod(workspace.root.path_join("mod.json"), archive).is_empty(), "Cannot export night vision: " + exporter.error)
	var zip := ZIPReader.new()
	check(zip.open(archive) == OK, "Cannot open night vision ZIP")
	var files := Array(zip.get_files()).filter(func(path): return not path.ends_with("/"))
	check(files.size() == 3, "Unexpected dependencies in night vision ZIP")
	var installed: String = workspace.root.path_join("installed")
	for file in files:
		var path := installed.path_join(str(file))
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		FileAccess.open(path, FileAccess.WRITE).store_buffer(zip.read_file(file))
	zip.close()
	var registry := preload("res://mod_registry.gd").new()
	check(registry.configure({}, [installed.path_join("mod.json")]).is_empty(), "Reopened vision mod rejected")
	var vision := Vision.new()
	check(vision.initialize(registry.postprocess, func(message): check(false, message)).is_empty(), "Reopened compositor rejected")
	check(vision.world.get("gain") == 4.5 and vision.background.get("gain") == 4.5, "Compositor edits lost on import")
	check(vision.world != vision.background and vision.world != effect, "Runtime shared the authored resource")
	check(vision.update({"vision_mode": 1, "actor_loop_tick": 20}) and vision.world.enabled and vision.background.enabled, "Night vision did not activate both views")
	check(not vision.update({"vision_mode": 1, "actor_loop_tick": 20}), "Paused repeated context reset history")
	vision.update({"vision_mode": 2, "actor_loop_tick": 21})
	check(not vision.world.enabled and not vision.background.enabled, "Night vision leaked into thermal mode")
	vision.update({"vision_mode": 0, "actor_loop_tick": 22})
	check(not vision.world.enabled and not effect.enabled, "Night vision changed source resource or stayed active")
	effect.set("gain", INF)
	check(not effect.call("validate").is_empty(), "Nonfinite compositor parameter accepted")
	RenderingServer.call_on_render_thread(vision.release)
	print("MGS_NIGHT_VISION_TEST failures=%d" % failures)
	quit(1 if failures else 0)
