extends SceneTree

const Scene = preload("res://scene_view.gd")
const PREFIX = "mgs/integral-j/disc1/stage/"
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var directory := "user://scene-preparation-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	var model := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.name = "mesh_000"
	mesh.mesh = BoxMesh.new()
	var empty := StandardMaterial3D.new()
	empty.resource_name = "0000"
	mesh.mesh.material = empty
	model.add_child(mesh)
	mesh.owner = model
	var packed := PackedScene.new()
	check(packed.pack(model) == OK and ResourceSaver.save(packed, directory.path_join("model.tscn")) == OK, "Cannot save preparation fixture")
	model.free()
	var scene := Scene.new()
	root.add_child(scene)
	scene.asset_root = directory
	scene.catalog = {}
	for stage in ["init", "s00a", "s01a"]:
		scene.catalog[PREFIX + stage + "/0001.k"] = {"kind":"model", "path":"model.tscn", "colorCount":4}
	# An unrelated malformed asset must not be instantiated while this map loads.
	scene.catalog[PREFIX + "s99a/0001.k"] = {"kind":"model", "path":"absent.tscn", "colorCount":4}
	check(scene.materials.initialize(scene.catalog, scene.mods, directory).is_empty(), "Cannot initialize fixture materials")
	check(scene.prepare_stage_models("s00a").is_empty(), "Cannot prepare first stage")
	check(scene.templates.size() == 2 and scene.prepared_instances.size() == 2, "Unrelated map models were eagerly instantiated")
	var resident: Node = scene.prepared_instances[PREFIX + "init/0001.k"].node
	check(scene.prepare_stage_models("s01a").is_empty(), "Cannot prepare next stage")
	check(scene.prepared_instances.size() == 2 and not scene.prepared_instances.has(PREFIX + "s00a/0001.k"), "Old stage preparation remained active")
	check(scene.prepared_instances[PREFIX + "init/0001.k"].node == resident, "Resident model was unnecessarily recreated")
	scene.free()
	print("MGS_SCENE_PREPARATION_TEST failures=%d" % failures)
	quit(1 if failures else 0)
