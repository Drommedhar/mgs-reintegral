extends SceneTree

var failures := 0

class NativeApi extends Node:
	signal native_context_updated
	var context := {"session_id": "snow-test", "epoch": 1, "actor_loop_tick": 0, "pause_mask": 0, "passage_ticks": 1}
	func get_native_context() -> Dictionary: return context

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	create_timer(45).timeout.connect(quit.bind(1))
	run.call_deferred()

func run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var api := NativeApi.new()
	scene.add_child(api)
	api.add_to_group("mgs_visual_api_v1")
	var roof := MeshInstance3D.new()
	roof.mesh = PlaneMesh.new()
	roof.mesh.size = Vector2(20,20)
	roof.rotation.x = PI
	roof.position.y = 1
	scene.add_child(roof)
	var volume: Node3D = load("res://addons/mgs_snow/snow_volume.tscn").instantiate()
	volume.amount = 128
	volume.wind_velocity = Vector3.ZERO
	volume.flutter_strength = 0
	scene.add_child(volume)
	volume.set_physics_process(false)
	volume.collision.prepare(100000)
	volume.collision.sync()
	await physics_frame
	await physics_frame
	volume.advance(1.0 / 60)
	var below_roof := 0
	var settled := 0
	for index in volume.particles.positions.size():
		if volume.particles.positions[index].y < 0.99: below_roof += 1
		if volume.particles.states[index] == 2: settled += 1
	check(below_roof == 0 and settled > 0, "Prewarmed snow spawned underneath a reversed roof")
	var landed: int = volume.particles.states.find(2)
	var landed_height: float = volume.particles.positions[landed].y
	roof.position.y += 0.5
	volume.collision.sync()
	volume.advance(0)
	check(is_equal_approx(volume.particles.positions[landed].y, landed_height + 0.5), "Settled flakes did not follow the moving surface")
	var before: PackedVector3Array = volume.particles.positions.duplicate()
	volume.update_native_time()
	volume.advance(1.0 / 60)
	api.context.pause_mask = 1
	before = volume.particles.positions.duplicate()
	var time: float = volume.particles.time
	api.context.actor_loop_tick += 1
	volume.update_native_time()
	check(volume.particles.positions == before and volume.particles.time == time, "Native pause did not freeze snow and contact fading")
	api.context.pause_mask = 0
	api.context.actor_loop_tick += 1
	volume.update_native_time()
	check(volume.particles.time > time, "Snow did not resume on the native clock")
	api.context.epoch += 1
	volume.update_native_time()
	check(volume.particles.time == 0 and volume.particles.states.count(0) == 128, "Scene reset retained stale flakes")
	check(volume.owns_native_snow(Vector3.ZERO) and not volume.owns_native_snow(Vector3(50,0,0)), "Original snow replacement escaped volume bounds")
	volume.replace_original_snow = false
	check(not volume.owns_native_snow(Vector3.ZERO), "Original snow replacement switch was ignored")
	volume.amount = 37
	volume.flake_size = Vector2(0.03,0.06)
	volume.fall_speed = 2.0
	var packed := PackedScene.new()
	check(packed.pack(volume) == OK, "Could not pack the snow volume")
	var path := "user://snow-volume-test.tscn"
	check(ResourceSaver.save(packed, path) == OK, "Could not save the snow volume")
	var serialized := FileAccess.get_file_as_string(path)
	check(not "ConcavePolygonShape3D" in serialized and not "PackedVector3Array" in serialized and not "MultiMesh" in serialized, "Snow saved locally derived collision/preview geometry")
	var reopened: Node3D = (load(path) as PackedScene).instantiate()
	check(reopened.amount == 37 and reopened.flake_size == Vector2(0.03,0.06) and reopened.fall_speed == 2.0, "Snow controls did not survive save/reopen")
	reopened.free()
	volume.free()
	scene.free()
	DirAccess.remove_absolute(path)
	print("MGS_SNOW_VOLUME_TEST failures=%d" % failures)
	quit(1 if failures else 0)
