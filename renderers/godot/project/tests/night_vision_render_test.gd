extends SceneTree

var viewport := SubViewport.new()
var background := SubViewport.new()
var vision := preload("res://vision_effects.gd").new()
var failures := 0
var fsr2 := "--fsr2" in OS.get_cmdline_user_args()

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func make_view(target: SubViewport, effect: CompositorEffect) -> void:
	target.size = Vector2i(128, 128)
	target.own_world_3d = true
	target.transparent_bg = target == viewport
	target.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2 if fsr2 else Viewport.SCALING_3D_MODE_BILINEAR
	target.scaling_3d_scale = 0.75 if fsr2 else 1.0
	target.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(target)
	var camera := Camera3D.new()
	camera.environment = Environment.new()
	camera.environment.background_mode = Environment.BG_COLOR
	camera.environment.background_color = Color(0.1, 0.2, 0.5)
	var compositor := Compositor.new()
	compositor.compositor_effects = [effect]
	camera.compositor = compositor
	target.add_child(camera)

func quad(color: Color, size: Vector2, position: Vector3) -> void:
	var node := MeshInstance3D.new()
	node.mesh = QuadMesh.new()
	node.mesh.size = size
	node.position = position
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1.0: material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	node.material_override = material
	viewport.add_child(node)

func frame() -> Image:
	for _index in 12: await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func run() -> void:
	check(vision.initialize({}, func(message): check(false, message)).is_empty(), "Cannot initialize compositor")
	for effect in [vision.world, vision.background]:
		effect.set("grain_strength", 0.0)
		effect.set("scanline_strength", 0.0)
	make_view(viewport, vision.world)
	make_view(background, vision.background)
	quad(Color(0.7, 0.04, 0.02), Vector2(0.8, 1.5), Vector3(-0.5, 0, -2))
	quad(Color(0.02, 0.04, 0.7, 0.5), Vector2(0.8, 1.5), Vector3(0.5, 0, -2))
	var original := await frame()
	var opaque := original.get_pixel(40, 64)
	var transparent := original.get_pixel(87, 64)
	check(opaque.r > opaque.g * 3 and transparent.b > transparent.g * 3, "Fixture colors missing")
	vision.update({"vision_mode": 1, "actor_loop_tick": 5})
	var filtered := await frame()
	for pixel in [Vector2i(40, 64), Vector2i(87, 64)]:
		var color := filtered.get_pixelv(pixel)
		check(color.g > color.r * 2 and color.g > color.b * 2, "Night vision did not filter opaque/transparent content: %s" % color)
		if not fsr2: check(absf(color.a - original.get_pixelv(pixel).a) < 0.01, "Night vision changed composition alpha")
	var empty_pixel := background.get_texture().get_image().get_pixel(64, 64)
	check(empty_pixel.g > empty_pixel.b * 2, "Background without geometry escaped night vision")
	vision.world.set("tint", Color(1, 0.1, 0.1))
	vision.update({"vision_mode": 1, "actor_loop_tick": 6})
	var customized := (await frame()).get_pixel(87, 64)
	check(customized.r > customized.g * 2, "Authored tint was not applied")
	vision.update({"vision_mode": 0, "actor_loop_tick": 7})
	var restored := await frame()
	var color := restored.get_pixel(40, 64)
	check(absf(color.r - opaque.r) < 0.03 and absf(color.g - opaque.g) < 0.03, "Turning goggles off did not restore scene color")
	RenderingServer.call_on_render_thread(vision.release)
	print("MGS_NIGHT_VISION_RENDER_TEST failures=%d fsr2=%s" % [failures, fsr2])
	quit(1 if failures else 0)
