extends SceneTree

const WorldEffects = preload("res://world_effects.gd")
const ReferenceMaterials = preload("res://reference_materials.gd")
const ModRegistry = preload("res://mod_registry.gd")
const Renderer = preload("res://renderer.gd")
const ReferenceShader = preload("res://reference_shader.gd")
const TEXTURE = "mgs/integral-j/disc1/stage/init/1234.p"
var viewport := SubViewport.new()
var effects := WorldEffects.new()
var materials := ReferenceMaterials.new()
var renderer := Renderer.new()
var camera := Camera3D.new()
var light := OmniLight3D.new()
var failures := 0
var expected := Color.BLACK

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func payload(blend: int, fade: float = 1.0, shift: float = 0.0) -> PackedByteArray:
	var bytes := PackedInt32Array([1, 0x1234]).to_byte_array()
	for point in [Vector3(-1, 1, -2), Vector3(1, 1, -2), Vector3(-1, -1, -2), Vector3(1, -1, -2)]:
		bytes.append_array(PackedFloat32Array([point.x + shift, point.y, point.z, 0, 0.5, 0.5, fade, fade, fade, blend, 0, 0]).to_byte_array())
	return bytes

func frame() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var folder := "user://effect-lighting-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.6, 0, 0))
	check(image.save_png(folder.path_join("albedo.png")) == OK, "Cannot create effect albedo")
	image.fill(Color.WHITE)
	check(image.save_png(folder.path_join("albedo.stp.png")) == OK, "Cannot create effect mask")
	var mods := ModRegistry.new()
	mods.stages.s00a = {"original_lighting": false}
	check(materials.initialize({TEXTURE: {"path": "albedo.png"}}, mods, folder).is_empty(), "Cannot initialize effect materials")
	viewport.size = Vector2i(64, 64)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.positional_shadow_atlas_size = 2048
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(effects)
	viewport.add_child(camera)
	camera.fov = 90
	camera.near = 0.01
	camera.environment = Environment.new()
	camera.environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	var compositor := Compositor.new()
	compositor.compositor_effects = [renderer.depth_capture]
	camera.compositor = compositor
	light.position = Vector3(0, 0.5, -0.5)
	light.omni_range = 10
	light.light_energy = 3
	light.shadow_enabled = true
	viewport.add_child(light)
	check(effects.update_effects(payload(1), 0, "d00a", materials).is_empty(), "Water effect payload rejected")
	var lit := await frame()
	var pixel := lit.get_pixel(32, 32)
	check(pixel.r > 0.1 and absf(pixel.a - 0.5) < 0.02, "Lit water lost light response or half transparency: %s" % pixel)
	light.hide()
	var dark := await frame()
	check(dark.get_pixel(32, 32).r < pixel.r * 0.2, "World effect remained unlit")
	light.show()
	var blocker := MeshInstance3D.new()
	blocker.mesh = BoxMesh.new()
	blocker.scale = Vector3.ONE * 0.5
	blocker.position = Vector3(0, 0.25, -1.2)
	blocker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	viewport.add_child(blocker)
	var shadowed := await frame()
	check(shadowed.get_pixel(32, 32).r < pixel.r * 0.8, "Water/particle did not receive a dynamic shadow")
	blocker.free()
	check(effects.update_effects(payload(2), 0, "d00a", materials).is_empty(), "Breath blend rejected")
	var additive := await frame()
	check(additive.get_pixel(32, 32).r > 0.1 and additive.get_pixel(32, 32).a < 0.02, "Additive breath lost its color/coverage")
	var reversed := payload(2)
	for corner in 4:
		reversed.encode_float(8 + corner * 48, -reversed.decode_float(8 + corner * 48))
	check(effects.update_effects(reversed, 0, "d00a", materials).is_empty(), "Back-facing ripple rejected")
	var backside := (await frame()).get_pixel(32, 32)
	check(absf(backside.r - additive.get_pixel(32, 32).r) < 0.02, "Back-facing ripple lost its lighting: %s" % backside)
	var batch: Dictionary = effects.batches[TEXTURE]
	check(effects.update_effects(payload(2, 0.25), 0, "d00a", materials).is_empty(), "Animated fade rejected")
	var faded := await frame()
	check(faded.get_pixel(32, 32).r < additive.get_pixel(32, 32).r * 0.7, "Native particle fade did not update")
	var ratio := faded.get_pixel(32, 32).srgb_to_linear().r / additive.get_pixel(32, 32).srgb_to_linear().r
	check(absf(ratio - 0.25) < 0.04, "Lighting crushed the native linear fade: %f" % ratio)
	check(effects.batches[TEXTURE].node == batch.node, "Effect geometry was rebuilt per frame")
	var burst := PackedInt32Array([64]).to_byte_array()
	for _quad in 64: burst.append_array(payload(2).slice(4))
	check(effects.update_effects(burst, 0, "d00a", materials).is_empty(), "Particle burst rejected")
	check(effects.batches[TEXTURE].node == batch.node, "A particle burst rebuilt the reserved mesh during playback")
	await check_overlapping_effects()
	await check_fog_fade()
	await check_original_surface()
	check(effects.update_effects(payload(1), 0, "d00a", materials).is_empty(), "Water restore failed")
	var restored := await frame()
	expected = restored.get_pixel(32, 32)
	renderer.world_texture = viewport.get_texture().get_rid()
	RenderingServer.call_on_render_thread(renderer.initialize.bind(ready))

func check_overlapping_effects() -> void:
	check(effects.update_effects(payload(2, 0.4), 0, "d00a", materials).is_empty(), "Single particle rejected")
	var single := (await frame()).get_pixel(32, 32).r
	var layered := payload(2, 0.4)
	var far := payload(2, 0.4)
	for corner in 4: far.encode_float(8 + corner * 48 + 8, -2.1)
	layered.encode_u32(0, 2)
	layered.append_array(far.slice(4))
	check(effects.update_effects(layered, 0, "d00a", materials).is_empty(), "Overlapping particles rejected")
	check((await frame()).get_pixel(32, 32).r > single * 1.2, "Near particle depth occluded the farther particle")
	var water := MeshInstance3D.new()
	water.mesh = QuadMesh.new()
	water.mesh.size = Vector2(4, 4)
	water.position.z = -2
	var blue := ShaderMaterial.new()
	blue.shader = Shader.new()
	blue.shader.code = "shader_type spatial; render_mode blend_premul_alpha, depth_draw_always, unshaded; void fragment() { ALBEDO = vec3(0.0, 0.0, 0.5); ALPHA = 0.5; PREMUL_ALPHA_FACTOR = 0.5; }"
	water.material_override = blue
	viewport.add_child(water)
	var ripple := payload(1)
	for corner in 4: ripple.encode_float(8 + corner * 48 + 12, 0.001)
	check(effects.update_effects(ripple, 0, "d00a", materials).is_empty(), "Surface ripple rejected")
	for angle in [-0.3, 0.0, 0.3]:
		camera.position.x = angle
		camera.look_at(Vector3(0, 0, -2))
		var pixel := (await frame()).get_pixel(32, 32)
		check(pixel.r > 0.1 and pixel.b > 0.1, "Coplanar ripple disappeared into water: %s" % pixel)
	water.position.z = -1.5
	blue.shader.code = "shader_type spatial; render_mode unshaded; void fragment() { ALBEDO = vec3(0.0, 0.0, 0.5); }"
	check((await frame()).get_pixel(32, 32).r < 0.02, "Ripple leaked through foreground geometry")
	water.free()
	camera.transform = Transform3D.IDENTITY

func check_fog_fade() -> void:
	for volumetric in [false, true]:
		camera.environment.fog_enabled = not volumetric
		camera.environment.fog_density = 0.4
		camera.environment.fog_light_color = Color(0.3, 0.5, 0.8)
		camera.environment.volumetric_fog_enabled = volumetric
		camera.environment.volumetric_fog_density = 0.4
		camera.environment.volumetric_fog_emission = Color(0.3, 0.5, 0.8)
		camera.environment.volumetric_fog_temporal_reprojection_enabled = false
		for blend in [2, 4]:
			check(effects.update_effects(payload(blend, 0.0), 0, "d00a", materials).is_empty(), "Faded ripple rejected")
			effects.hide()
			var background := (await frame()).get_pixel(32, 32)
			effects.show()
			var faded := (await frame()).get_pixel(32, 32)
			check(absf(faded.r - background.r) + absf(faded.g - background.g) + absf(faded.b - background.b) < 0.02,
				"Fog revealed an invisible additive quad: volumetric=%s blend=%d before=%s after=%s" % [volumetric, blend, background, faded])
	camera.environment.fog_enabled = false
	camera.environment.volumetric_fog_enabled = false

func check_original_surface() -> void:
	effects.hide()
	var mesh := MeshInstance3D.new()
	mesh.mesh = QuadMesh.new()
	mesh.mesh.size = Vector2(2, 2)
	mesh.position.z = -2
	var material := ShaderMaterial.new()
	materials.pbr.apply(material, TEXTURE, false)
	material.shader = ReferenceShader.transparent(material.shader)
	material.set_shader_parameter("albedo_texture", materials.texture_for(TEXTURE, false))
	material.set_shader_parameter("mask_texture", materials.texture_for(TEXTURE, true))
	var shade := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	shade.fill(Color(0.5, 0.5, 0.5, 1))
	material.set_shader_parameter("shade_texture", ImageTexture.create_from_image(shade))
	var packet := Image.create(1, 1, false, Image.FORMAT_RGBAF)
	packet.fill(Color(0.5, 0.5, 2000, 1))
	material.set_shader_parameter("packet_texture", ImageTexture.create_from_image(packet))
	material.next_pass = materials.transparent_depth({"shade": material.get_shader_parameter("shade_texture"),
		"packets": material.get_shader_parameter("packet_texture")}, StandardMaterial3D.new(), TEXTURE, false)
	mesh.material_override = material
	viewport.add_child(mesh)
	var lit := (await frame()).get_pixel(32, 32)
	light.hide()
	var dark := (await frame()).get_pixel(32, 32)
	check(lit.r > 0.1 and absf(lit.a - 0.5) < 0.02 and dark.r < lit.r * 0.2, "Original transparent model did not use Godot lighting and blending")
	light.show()
	var background := MeshInstance3D.new()
	background.mesh = QuadMesh.new()
	background.mesh.size = Vector2(4, 4)
	background.position.z = -4
	var blue := StandardMaterial3D.new()
	blue.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blue.albedo_color = Color.BLUE
	background.material_override = blue
	viewport.add_child(background)
	var over_geometry := (await frame()).get_pixel(32, 32)
	check(over_geometry.b > 0.2, "Transparent model occluded the opaque world behind it: %s" % over_geometry)
	effects.show()
	var behind_water := payload(2)
	for corner in 4: behind_water.encode_float(8 + corner * 48 + 8, -2.05)
	check(effects.update_effects(behind_water, 0, "d00a", materials).is_empty(), "Subsurface ripple rejected")
	var with_ripple := (await frame()).get_pixel(32, 32)
	check(with_ripple.r > over_geometry.r + 0.1, "Transparent water depth erased the ripple: %s versus %s" % [with_ripple, over_geometry])
	background.position.z = -1.5
	check((await frame()).get_pixel(32, 32).r < 0.02, "Subsurface ripple leaked through solid foreground geometry")
	background.free()
	mesh.free()
	effects.show()

func ready(_texture: RID, error: String) -> void:
	check(error.is_empty(), error)
	var commands := [[8, PackedInt32Array([0, 0, 64, 64, 0, 248, 0]).to_byte_array()],
		[10, PackedInt32Array([0, 0, 64, 64, 0, 0, 0, 65536, 0, 0, 64, 64, 0]).to_byte_array()]]
	RenderingServer.call_on_render_thread(renderer.execute.bind(commands, 5, PackedInt32Array([32, 32, 1, 1]).to_byte_array(), composed))

func composed(_operation: int, _payload: PackedByteArray, pixels: PackedByteArray, error: String) -> void:
	check(error.is_empty(), error)
	if pixels.size() == 4:
		check(absf(pixels[0] / 255.0 - expected.r) < 0.02 and absf(pixels[1] / 255.0 - (1.0 - expected.a)) < 0.02,
			"Water did not blend with the compatibility background: %s expected %s" % [pixels, expected])
	else: check(false, "Effect composition returned no pixel")
	check(not effects.update_effects(payload(1).slice(0, 40), 0, "d00a", materials).is_empty(), "Truncated effects accepted")
	check(effects.update_effects(PackedInt32Array([0]).to_byte_array(), 0, "d00a", materials).is_empty(), "Empty effects rejected")
	check(not effects.batches[TEXTURE].node.visible, "Expired effect remained visible")
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	camera.compositor = null
	RenderingServer.call_on_render_thread(renderer.release.bind(finished))

func finished() -> void:
	viewport.free()
	await process_frame
	print("MGS_WORLD_EFFECTS_TEST failures=%d" % failures)
	quit(1 if failures else 0)
