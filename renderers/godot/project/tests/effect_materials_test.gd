extends SceneTree

const Authoring = preload("res://addons/mgs_editor/effect_authoring.gd")
const Workspace = preload("res://addons/mgs_editor/mod_workspace.gd")
const Registry = preload("res://mod_registry.gd")
const Export = preload("res://addons/mgs_editor/mod_export.gd")
const Effects = preload("res://effect_materials.gd")
const WorldEffects = preload("res://world_effects.gd")
const TEXTURE = "mgs/integral-j/disc1/stage/s00a/1234.p"
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var workspace := Workspace.new()
	workspace.root = "user://effect-mod-%d" % Time.get_ticks_usec()
	var authoring := Authoring.new()
	var material := authoring.open_material(workspace, Effects.SNOW)
	check(material != null, "Cannot create effect material: " + authoring.error)
	if material == null:
		quit(1)
		return
	material.set_shader_parameter("effect_tint", Color(0.2, 0.7, 1.0, 0.8))
	material.set_shader_parameter("beam_width", 3.5)
	material.set_shader_parameter("beam_heat", 0.6)
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	image.set_pixel(0, 0, Color.TRANSPARENT)
	var texture_path := material.resource_path.get_base_dir().path_join("flake.png")
	check(image.save_png(texture_path) == OK, "Cannot save custom effect texture")
	var custom := ImageTexture.create_from_image(image)
	custom.take_over_path(texture_path)
	material.set_shader_parameter("custom_texture", custom)
	material.set_shader_parameter("use_custom_texture", true)
	check(ResourceSaver.save(material, material.resource_path) == OK, "Cannot save authored material")
	check(authoring.open_material(workspace, Effects.SNOW) == material, "Reopening replaced existing edits")
	var lamp := authoring.open_material(workspace, TEXTURE)
	check(lamp != null, "Cannot create textured effect override")
	var catalog := {TEXTURE:{"kind":"texture", "sha256":"matching"}, TEXTURE.replace("s00a", "d00a"):{"kind":"texture", "sha256":"matching"}}
	var registry := Registry.new()
	check(registry.configure(catalog, [workspace.root.path_join("mod.json")]).is_empty(), "Valid effect manifest rejected")
	check(registry.effects.has(TEXTURE.replace("s00a", "d00a")), "Matching cinematic effect did not inherit override")
	var appearance := Effects.new()
	check(appearance.initialize(registry.effects).is_empty(), "Cannot load authored effects")
	var pair := appearance.pair(Effects.SNOW, WorldEffects.SHADER, WorldEffects.DEPTH_SHADER)
	check(pair[0] != material and pair[0].get_shader_parameter("effect_tint") == material.get_shader_parameter("effect_tint"), "Runtime mutated or ignored source material")
	check(pair[1].get_shader_parameter("custom_texture").get_image().get_pixel(0, 0).a == 0.0 and pair[1].get_shader_parameter("effect_tint") == material.get_shader_parameter("effect_tint"), "Depth lost authored appearance parameters")
	var archive := workspace.root.path_join("effects.zip")
	check(Export.new().export_mod(workspace.root.path_join("mod.json"), archive).is_empty(), "Effect ZIP export failed")
	var zip := ZIPReader.new()
	check(zip.open(archive) == OK, "Cannot open effect ZIP")
	var files := Array(zip.get_files()).filter(func(path): return not path.ends_with("/"))
	check(files.size() == 12, "Effect ZIP dependencies missing or unexpected")
	var installed := workspace.root.path_join("installed")
	for file in files:
		var path := installed.path_join(str(file))
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		FileAccess.open(path, FileAccess.WRITE).store_buffer(zip.read_file(file))
	zip.close()
	var reopened := Registry.new()
	check(reopened.configure(catalog, [installed.path_join("mod.json")]).is_empty(), "Reopened effect manifest rejected")
	var loaded := Effects.new()
	check(loaded.initialize(reopened.effects).is_empty(), "Relocated shaders/includes failed to load")
	var restored: ShaderMaterial = loaded.definitions[Effects.SNOW].material
	check(restored.get_shader_parameter("beam_width") == 3.5 and is_equal_approx(restored.get_shader_parameter("beam_heat"), 0.6), "ZIP reopening lost beam width/heat")
	check(restored.get_shader_parameter("custom_texture").get_image().get_pixel(0, 0).a == 0.0, "ZIP reopening lost PNG alpha")
	var reopened_workspace := Workspace.new()
	reopened_workspace.root = installed
	check(Authoring.new().open_material(reopened_workspace, Effects.SNOW) != null, "Reopened effect cannot be edited")
	check_errors(workspace, catalog)
	print("MGS_EFFECT_MATERIALS_TEST failures=%d" % failures)
	quit(1 if failures else 0)

func check_errors(workspace: RefCounted, catalog: Dictionary) -> void:
	var manifest: Dictionary = workspace.manifest()
	manifest.root = workspace.root
	manifest.effects[Effects.SNOW].depth_shader = "../outside.gdshader"
	check("inside the mod folder" in Registry.new().register_manifest(catalog, manifest), "External effect shader accepted")
	manifest.effects = {"unknown": {}}
	check("Unknown world-effect" in Registry.new().register_manifest(catalog, manifest), "Unknown effect identity accepted")
	var shader := Shader.new()
	shader.code = "shader_type spatial; void fragment() { ALBEDO = vec3(1.0); }"
	check("native input" in Effects.validate_shader(shader), "Shader without native geometry contract accepted")
	var original_material := ShaderMaterial.new()
	original_material.shader = WorldEffects.SHADER
	var path: String = workspace.root.path_join("external.tres")
	ResourceSaver.save(original_material, path)
	var export := Export.new()
	export.root = ProjectSettings.globalize_path(workspace.root)
	export.collect(path)
	check("outside the mod folder" in export.error, "Effect export included SDK/original external dependencies")
