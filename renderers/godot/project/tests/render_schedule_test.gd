extends SceneTree

const Schedule = preload("res://render_schedule.gd")
var schedule := Schedule.new()
var viewport := SubViewport.new()
var failures: Array[String] = []
var draws := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func pixel() -> Color:
	return viewport.get_texture().get_image().get_pixel(32, 32)

func run() -> void:
	root.add_child(schedule)
	viewport.size = Vector2i(64, 64)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	root.add_child(viewport)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	var mesh := MeshInstance3D.new()
	mesh.mesh = QuadMesh.new()
	mesh.position.z = -2
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color.RED
	mesh.material_override = material
	viewport.add_child(mesh)
	await RenderingServer.frame_post_draw
	check(pixel().r > 0.9, "Initial world must render")
	RenderingServer.frame_pre_draw.connect(func(): draws += 1)
	schedule.start()
	check(not RenderingServer.render_loop_enabled, "Protocol polling must not submit automatic GPU frames")
	for _poll in 8: await process_frame
	check(draws <= 2, "Idle protocol polls must not each draw a GPU frame")
	mesh.position.x = 10
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await schedule.world()
	check(pixel().r < 0.3, "World draw must include the latest deferred transform")
	mesh.position.x = 0
	material.albedo_color = Color.BLUE
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await schedule.world()
	check(pixel().b > 0.9 and pixel().r < 0.1, "World composition must receive current geometry and material")
	var overlay := ColorRect.new()
	overlay.size = Vector2(64, 64)
	overlay.color = Color.GREEN
	viewport.add_child(overlay)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	schedule.present()
	await process_frame
	await process_frame
	check(pixel().g > 0.9 and pixel().b < 0.1, "Presentation must flush deferred CanvasItem redraws")
	overlay.color = Color.BLUE
	await create_timer(0.12).timeout
	check(pixel().b > 0.9 and pixel().g < 0.1, "Loading UI must redraw while native replies are pending")
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; render_mode unshaded; void fragment() { COLOR = vec4(fract(TIME / 10.0), 0.0, 0.0, 1.0); }"
	var timed := ShaderMaterial.new()
	timed.shader = shader
	overlay.material = timed
	schedule.present()
	await process_frame
	await process_frame
	var before := pixel().r
	await create_timer(0.2).timeout
	var advance := fposmod(pixel().r - before, 1.0)
	check(advance > 0.01 and advance < 0.08, "Manual draws must advance shader TIME at wall-clock speed")
	schedule.stop()
	check(RenderingServer.render_loop_enabled, "Stopping must restore automatic rendering")
	viewport.queue_free()
	schedule.queue_free()
	await process_frame
	print("RENDER_SCHEDULE_TEST failures=", failures.size())
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
