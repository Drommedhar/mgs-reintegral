extends SceneTree

const History = preload("res://camera_history.gd")
const SceneView = preload("res://scene_view.gd")
var failures := 0
var viewports: Array[SubViewport] = []
var cameras: Array[Camera3D] = []

class BufferWitness extends CompositorEffect:
	var color_rid: RID

	func _init() -> void:
		effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT

	func _render_callback(_type: int, data: RenderData) -> void:
		color_rid = data.get_render_scene_buffers().get_color_layer(0)

func check(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)

func _initialize() -> void:
	run.call_deferred()

func viewport(environment: Environment, material: Material) -> SubViewport:
	var view := SubViewport.new()
	view.size = Vector2i(192, 128)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	SceneView.configure_rendering(view, root)
	root.add_child(view)
	var camera := Camera3D.new()
	view.add_child(camera)
	camera.environment = environment
	var wall := MeshInstance3D.new()
	wall.mesh = QuadMesh.new()
	wall.mesh.size = Vector2(20, 20)
	wall.position.z = -5
	wall.material_override = material
	view.add_child(wall)
	viewports.append(view)
	cameras.append(camera)
	return view

func difference(a: Image, b: Image) -> float:
	var error := 0.0
	for y in range(16, 112):
		for x in range(16, 176):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			error += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
	return error / (160.0 * 96.0 * 3.0)

func run() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.BLACK
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.15
	environment.volumetric_fog_length = 12.0
	environment.volumetric_fog_emission = Color(1, 0.05, 0.05)
	environment.volumetric_fog_temporal_reprojection_enabled = true
	environment.volumetric_fog_temporal_reprojection_amount = 0.99
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.1, 0.1, 0.1)
	var reset_view := viewport(environment, material)
	var stale_view := viewport(environment, material)
	var fresh_view := viewport(environment, material)
	var witness := BufferWitness.new()
	var compositor := Compositor.new()
	compositor.compositor_effects = [witness]
	cameras[0].compositor = compositor
	reset_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	stale_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for index in 120: await RenderingServer.frame_post_draw
	var old_color := witness.color_rid
	var history := History.new()
	environment.volumetric_fog_emission = Color(0.05, 0.05, 1)
	for camera in cameras: camera.rotation.y = 0.02
	# A fresh view uses zero history weight too: its fog texture starts empty.
	cameras[2].environment = environment.duplicate()
	cameras[2].environment.volumetric_fog_temporal_reprojection_amount = 0.0
	var start := Time.get_ticks_usec()
	history.begin(cameras[0])
	fresh_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var cut_ms := (Time.get_ticks_usec() - start) / 1000.0
	var reset_image := reset_view.get_texture().get_image()
	var stale_image := stale_view.get_texture().get_image()
	var fresh_image := fresh_view.get_texture().get_image()
	check(witness.color_rid != old_color, "Cut did not rebuild FSR2 render buffers")
	check(reset_view.scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR2 and reset_view.scaling_3d_scale == 1.0, "Cut changed AA settings")
	check(is_equal_approx(environment.volumetric_fog_temporal_reprojection_amount, 0.99), "Cut modified shared authored environment")
	var reset_error := difference(reset_image, fresh_image)
	var stale_error := difference(stale_image, fresh_image)
	check(reset_error < 0.025, "First cut frame retains previous fog/FSR2 image")
	check(stale_error > reset_error + 0.1, "Fixture did not expose retained temporal history")
	history.finish(cameras[0])
	check(cameras[0].environment == environment, "Cut did not restore authored environment")
	var reset_color := witness.color_rid
	await RenderingServer.frame_post_draw
	check(witness.color_rid == reset_color, "Normal following frame rebuilt render buffers")
	check(difference(reset_view.get_texture().get_image(), fresh_image) < 0.025, "Previous-shot fog returned after reset frame")
	# The world-environment path must return camera ownership to null.
	cameras[0].environment = null
	reset_view.find_world_3d().environment = environment
	history.begin(cameras[0])
	check(cameras[0].environment != null, "World environment was not reset")
	await RenderingServer.frame_post_draw
	history.finish(cameras[0])
	check(cameras[0].environment == null, "World environment reset retained a camera override")
	print("MGS_CAMERA_HISTORY_TEST reset_error=%.6f stale_error=%.6f cut_ms=%.2f failures=%d" % [reset_error, stale_error, cut_ms, failures])
	for view in viewports: view.free()
	quit(1 if failures else 0)
