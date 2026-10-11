extends SceneTree

const SceneView = preload("res://scene_view.gd")
const TEXTURE = "mgs/integral-j/disc1/stage/init/1234.p"
var scene := SceneView.new()
var viewport := SubViewport.new()
var failures := 0

func check(condition: bool, message: String) -> void:
	if condition: return
	push_error(message)
	failures += 1

func texture(color: Color, format: Image.Format) -> ImageTexture:
	var image := Image.create(1, 1, false, format)
	image.fill(color)
	return ImageTexture.create_from_image(image)

func part(x: float) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = QuadMesh.new()
	mesh.position.x = x
	var source := StandardMaterial3D.new()
	source.resource_name = "1234"
	mesh.mesh.material = source
	return mesh

func frame() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	viewport.size = Vector2i(128, 128)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(scene)
	scene.add_child(scene.camera)
	scene.camera.position.z = 4
	scene.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	scene.camera.size = 4
	scene.camera.cull_mask &= ~scene.materials.METADATA_LAYER
	scene.camera.environment = Environment.new()
	scene.camera.environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	var folder := "user://alarm-glass-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	check(texture(Color(0.8, 0.02, 0.01), Image.FORMAT_RGBA8).get_image().save_png(folder.path_join("glass.png")) == OK, "Cannot write glass texture")
	check(texture(Color.WHITE, Image.FORMAT_RGBA8).get_image().save_png(folder.path_join("glass.stp.png")) == OK, "Cannot write glass mask")
	scene.mods.stages.s00a = {"original_lighting": false}
	check(scene.materials.initialize({TEXTURE: {"path": "glass.png"}}, scene.mods, folder).is_empty(), "Cannot initialize glass materials")
	var node := Node3D.new()
	scene.add_child(node)
	var entry := {"asset": "mgs/integral-j/disc1/stage/init/0001.k", "node": node,
		"meshes": [part(-0.75), part(0.75)], "transparent_parts": {0: true},
		"material_stages": {}, "surface_materials": {}, "shadow_modes": [1, 1],
		"shade": texture(Color(0.5, 0.5, 0.5, 1), Image.FORMAT_RGBA8),
		"packets": texture(Color(0.5, 0.5, 4000, 1), Image.FORMAT_RGBAF),
		"alarm_glass": true, "alarm_active": false}
	for mesh in entry.meshes: node.add_child(mesh)
	scene.materials.add_metadata_meshes(entry)
	scene.set_part_visibility(entry, 0, 7)
	scene.set_part_visibility(entry, 1, 3)
	check(entry.meshes[0].cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Glass blocks the beacon lights")
	check(entry.meshes[1].cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "Opaque housing lost its shadow")
	check(scene.materials.apply(entry, "s00a").is_empty(), "Inactive beacon materials rejected")
	var inactive := await frame()
	check(inactive.get_pixel(40, 64).r < 0.02, "Inactive glass is emissive")
	entry.alarm_active = true
	check(scene.materials.apply(entry, "s00a").is_empty(), "Active beacon materials rejected")
	var active := await frame()
	var glass := active.get_pixel(40, 64)
	check(glass.r > 0.5 and glass.g < 0.05, "Active glass does not glow red without external lighting: %s" % glass)
	check(active.get_pixel(88, 64).r < 0.02, "The opaque housing became emissive")
	entry.alarm_active = false
	check(scene.materials.apply(entry, "s00a").is_empty(), "Beacon deactivation rejected")
	check((await frame()).get_pixel(40, 64).r < 0.02, "Glass kept glowing after the alarm stopped")
	viewport.free()
	print("MGS_ALARM_GLASS_TEST failures=%d" % failures)
	quit(1 if failures else 0)
