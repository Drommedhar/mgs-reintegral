extends SceneTree

var ticks := 0
var failures := 0
var reports: Array[String] = []

func check(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)

func _initialize() -> void:
	process_frame.connect(func(): ticks += 1)
	run.call_deferred()

func run() -> void:
	var path := "user://scene-resources-%d.tscn" % Time.get_ticks_usec()
	FileAccess.open(path, FileAccess.WRITE).store_string('[gd_scene format=3]\n[node name="AuthoredMap" type="Node3D"]\n')
	var loader := preload("res://scene_resources.gd").new()
	var amounts: Array[float] = []
	var report := func(message: String, percent: float):
		reports.append(message)
		amounts.append(percent)
	var error := await loader.prepare([path], self, report)
	check(error.is_empty() and ticks > 0 and not reports.is_empty(), "Scene load blocked without progress: " + error)
	check(loader.retained.size() == 1 and loader.retained[0] is PackedScene, "Completed scene was not retained for instantiation")
	check(amounts[-1] == 100, "Scene load progress never reached completion")
	var scene: Node = load(path).instantiate()
	check(scene.name == "AuthoredMap", "Prepared scene could not be instantiated")
	scene.free()
	check((await loader.prepare([], self, report)).is_empty() and loader.retained.is_empty(), "Prior stage resources were retained after transition")
	check(not (await loader.prepare(["user://absent-mod-scene.tscn"], self, report)).is_empty(), "Failed scene load was silently accepted")
	DirAccess.remove_absolute(path)
	print("MGS_SCENE_RESOURCES_TEST failures=%d" % failures)
	quit(1 if failures else 0)
