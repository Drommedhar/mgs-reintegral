extends SceneTree

var failures := 0

class NativeApi extends Node:
	signal native_context_updated
	var context := {"session_id": "gpu-snow-test", "epoch": 1, "actor_loop_tick": 0, "pause_mask": 0, "passage_ticks": 2}
	func get_native_context() -> Dictionary: return context

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	create_timer(45).timeout.connect(quit.bind(1))
	run.call_deferred()

func image_after_draw(viewport: SubViewport) -> Image:
	for frame in 3: await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func particle_bounds(snow: Node3D) -> AABB:
	var mesh_margin: float = snow.gpu.draw.draw_pass_1.get_aabb().get_longest_axis_size()
	return snow.gpu.draw.capture_aabb().grow(-mesh_margin)

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320,320)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene := Node3D.new()
	viewport.add_child(scene)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	scene.add_child(environment)
	var api := NativeApi.new()
	scene.add_child(api)
	api.add_to_group("mgs_visual_api_v1")
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(0,2,8)
	camera.look_at(Vector3.ZERO)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.0
	var roof := MeshInstance3D.new()
	roof.mesh = BoxMesh.new()
	roof.mesh.size = Vector3(6,0.2,6)
	scene.add_child(roof)
	var snow: Node3D = load("res://addons/mgs_snow/snow_volume.tscn").instantiate()
	snow.volume_size = Vector3(4,4,4)
	snow.amount = 1000
	snow.flake_size = Vector2(0.04,0.06)
	snow.wind_velocity = Vector3.ZERO
	snow.flutter_strength = 0.0
	snow.settle_time = 5.0
	scene.add_child(snow)
	snow.set_physics_process(false)
	snow.material.set_shader_parameter("flake_color", Color.WHITE)
	snow.update_native_time()
	for frame in 10:
		api.context.actor_loop_tick += 1
		snow.update_native_time()
		await RenderingServer.frame_post_draw
	check(snow.gpu != null and snow.gpu.draw is GPUParticles3D, "Snow did not use Godot GPU particles")
	check(snow.collision.entries.is_empty() and snow.collision.pending.is_empty() and snow.particles.positions.is_empty(), "GPU snow still prepared or simulated CPU flakes/collision")
	var bounds := particle_bounds(snow)
	print("MGS_SNOW_GPU_BOUNDS ", bounds)
	check(bounds.size.length() > 1.0 and bounds.position.y > 0.09, "GPU flakes spawned beneath the weather roof or failed to emit")
	var before := await image_after_draw(viewport)
	var paused_bounds: AABB = snow.gpu.draw.capture_aabb()
	api.context.pause_mask = 1
	var time: float = snow.gpu.time
	for frame in 10:
		api.context.actor_loop_tick += 1
		snow.update_native_time()
		await RenderingServer.frame_post_draw
	check(snow.gpu.time == time and paused_bounds == snow.gpu.draw.capture_aabb(), "Native pause did not freeze GPU snow")
	api.context.pause_mask = 0
	for frame in 10:
		api.context.actor_loop_tick += 1
		snow.update_native_time()
		await RenderingServer.frame_post_draw
	var resumed := await image_after_draw(viewport)
	check(before.get_data() != resumed.get_data(), "GPU snow did not visibly resume")
	roof.position.y = 0.5
	for frame in 5:
		api.context.actor_loop_tick += 1
		snow.update_native_time()
		await RenderingServer.frame_post_draw
	bounds = particle_bounds(snow)
	check(bounds.position.y > 0.59, "GPU weather collision did not refresh for moving geometry")
	api.context.epoch += 1
	snow.update_native_time()
	check(snow.gpu.time == 0.0, "Native epoch did not reset GPU snow")
	snow.amount = 37
	check(snow.gpu.draw.amount == 37, "GPU flake count ignored the authoring control")
	snow.amount = 0
	snow.flush_gpu()
	check(not snow.gpu.draw.visible and not snow.gpu.heightfield.visible and not snow.owns_native_snow(Vector3.ZERO), "Zero flakes retained visible snow, collision or original-snow suppression")
	snow.amount = 37
	var packed := PackedScene.new()
	check(packed.pack(snow) == OK, "GPU snow could not be packed")
	var path := "user://gpu-snow-test.tscn"
	check(ResourceSaver.save(packed, path) == OK, "GPU snow could not be saved")
	var serialized := FileAccess.get_file_as_string(path)
	check(not "GPUParticles3D" in serialized and not "HeightField" in serialized, "Generated GPU snow/collision was saved into the mod scene")
	var reopened: Node3D = (load(path) as PackedScene).instantiate()
	check(reopened.simulation_mode == 0 and reopened.amount == 37, "GPU mode or flake count changed after scene reopening")
	reopened.free()
	DirAccess.remove_absolute(path)
	snow.simulation_mode = 1
	check(snow.gpu == null and snow.particles.positions.size() == 37, "Exact CPU mode did not restore particle simulation")
	snow.simulation_mode = 0
	check(snow.gpu != null and snow.collision.pending.is_empty() and snow.particles.positions.is_empty(), "Switching back to GPU weather retained CPU work")
	viewport.free()
	print("MGS_SNOW_GPU_TEST failures=%d" % failures)
	quit(1 if failures else 0)
