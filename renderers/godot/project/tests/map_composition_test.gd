extends SceneTree

const DiscMap = preload("res://addons/mgs_editor/disc_map.gd")
const SceneView = preload("res://scene_view.gd")
const MapSource = preload("res://map_source.gd")
const MapAuthoring = preload("res://addons/mgs_editor/map_authoring.gd")
const ModExport = preload("res://addons/mgs_editor/mod_export.gd")
const Profile = preload("res://mod_profile.gd")
const ProfilePreview = preload("res://addons/mgs_editor/profile_preview.gd")
const Removals = preload("res://visual_removals.gd")
const Registry = preload("res://mod_registry.gd")
const ASSET = "mgs/integral-j/disc1/stage/s00a/0001.k"
const TEXTURE = "mgs/integral-j/disc1/stage/s00a/0002.p"
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	run.call_deferred()

func save_scene(node: Node, path: String) -> void:
	var packed := PackedScene.new()
	check(packed.pack(node) == OK and ResourceSaver.save(packed, path) == OK, "Cannot save composition fixture")

func fixture(directory: String) -> Dictionary:
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.5, 0.5, 1.0))
	check(image.save_png(directory.path_join("custom.png")) == OK, "Cannot save custom PBR fixture")
	var original := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.name = "mesh_000"
	mesh.mesh = QuadMesh.new()
	var material := StandardMaterial3D.new()
	material.resource_name = "0002_fixture"
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = ImageTexture.create_from_image(image)
	mesh.mesh.material = material
	original.add_child(mesh)
	mesh.owner = original
	save_scene(original, directory.path_join("original.tscn"))
	original.free()
	return {"disc":1, "edition":"integral-j", "stageDirSha256":"original-stage", "sourceImageSha256":"original-disc",
		"maps":{"s00a":{"models":[ASSET], "lights":[], "script_sha256":"script"}, "d00a":{"models":[], "lights":[]}},
		"assets":{ASSET:{"kind":"model", "path":"original.tscn", "parts":1}, TEXTURE:{"kind":"texture", "path":"custom.png"}}}

func pbr_and_layers(directory: String, prepared: Dictionary) -> void:
	var base := {"schema":1, "id":"base", "priority":1, "materials":{TEXTURE:{"roughness":0.7}}}
	var top := {"schema":1, "id":"finish", "priority":2, "materials":{TEXTURE:{"albedo":"custom.png", "normal":"custom.png", "orm":"custom.png", "emission":"custom.png", "roughness":0.31, "metallic":0.6, "normal_scale":0.75, "emission_energy":2.5}}}
	for manifest in [base, top]:
		FileAccess.open(directory.path_join(manifest.id + ".json"), FileAccess.WRITE).store_string(JSON.stringify(manifest))
	var paths := [directory.path_join("finish.json"), directory.path_join("base.json")]
	var loader := DiscMap.new()
	var map := loader.load_map(directory, prepared, "s00a", "", "", paths)
	check(map != null, loader.error)
	if map == null: return
	root.add_child(map)
	var preview: StandardMaterial3D = map.get_child(0).get_node("mesh_000").get_active_material(0)
	var runtime := SceneView.new()
	root.add_child(runtime)
	check(runtime.mods.configure(prepared.assets, paths).is_empty(), "Runtime rejected composition manifests")
	check(runtime.materials.pbr.initialize(runtime.mods.materials).is_empty(), "Runtime rejected custom PBR images")
	var shaded := ShaderMaterial.new()
	runtime.materials.pbr.apply(shaded, TEXTURE, false)
	check(loader.mods.conflicts == runtime.mods.conflicts, "Editor/runtime conflict resolution differs")
	check(preview.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL, "Editor ignored PBR lighting")
	check(is_equal_approx(preview.roughness, shaded.get_shader_parameter("pbr_roughness")), "Editor/runtime roughness differs")
	check(is_equal_approx(preview.metallic, shaded.get_shader_parameter("pbr_metallic")), "Editor/runtime metallic differs")
	check(preview.normal_enabled and preview.ao_enabled and preview.emission_enabled, "Editor omitted normal/ORM/emission maps")
	check(is_equal_approx(preview.normal_scale, shaded.get_shader_parameter("normal_scale")), "Editor/runtime normal scale differs")
	check(is_equal_approx(preview.emission_energy_multiplier, shaded.get_shader_parameter("emission_energy")), "Editor/runtime emission energy differs")
	check(preview.ao_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_RED and preview.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_GREEN and preview.metallic_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_BLUE, "ORM channels differ from runtime")
	check(preview.albedo_texture.get_image().get_pixel(0, 0).is_equal_approx(Color8(128, 128, 255)), "Editor ignored PBR albedo")
	map.free()
	runtime.free()

func source_validation(directory: String, prepared: Dictionary) -> void:
	var authored := Node3D.new()
	authored.set_meta("mgs_scene_source", MapSource.describe(prepared, "s00a"))
	authored.set_meta("mgs_removals", [{"asset":ASSET}])
	var addition := OmniLight3D.new()
	addition.name = "CustomLight"
	addition.light_energy = 3.5
	authored.add_child(addition)
	addition.owner = authored
	var path := directory.path_join("stage.tscn")
	save_scene(authored, path)
	var runtime := SceneView.new()
	root.add_child(runtime)
	runtime.catalog = {}
	runtime.content.catalogs[1] = prepared
	runtime.content.assets = prepared.assets.duplicate(true)
	var variant := ASSET.replace("s00a", "d00a")
	runtime.content.assets[ASSET].sha256 = "same-model"
	runtime.content.assets[variant] = runtime.content.assets[ASSET].duplicate(true)
	runtime.content.assets[variant].sha256 = "variant-model"
	runtime.content.assets[variant].parts = 2
	runtime.catalog = runtime.content.assets
	runtime.mods.stages.s00a = {"path":path, "mod":"source.test"}
	check(runtime.materials.initialize(runtime.catalog, runtime.mods, directory).is_empty(), "Cannot initialize stage composition materials")
	runtime.asset_root = directory
	check(runtime.change_stage("d00a").is_empty(), "Inherited map checked the target script instead of its authored source")
	var original := Node3D.new()
	var entry := {"asset":variant, "node":original, "meshes":[], "metadata_meshes":[]}
	runtime.removals.apply(entry, 1)
	check(not original.visible, "Inherited whole-model hide did not hide different variant geometry in game")
	original.show()
	runtime.removals.apply(entry, 1)
	check(not original.visible, "Native visibility reset restored an authored hidden model")
	original.free()
	var authoring := MapAuthoring.new()
	var fork := authoring.create_map(runtime.mods, runtime.content, "d00a", 1)
	check(fork != null, authoring.error)
	if fork != null:
		check(fork.has_node("CustomLight") and is_equal_approx(fork.get_node("CustomLight").light_energy, 3.5), "Opening an inherited map lost authored nodes")
		check(fork.get_meta("mgs_removals")[0].asset == variant, "Inherited map removals were not resolved to matching variant assets")
		check(MapSource.validate(fork.get_meta("mgs_scene_source"), prepared, "d00a").is_empty(), "New variant retained the parent map source fingerprint")
		var fork_path := directory.path_join("fork.tscn")
		save_scene(fork, fork_path)
		var manifest := {"schema":1, "id":"fork.test", "stages":{"d00a":{"scene":"fork.tscn"}}}
		var manifest_path := directory.path_join("fork.json")
		FileAccess.open(manifest_path, FileAccess.WRITE).store_string(JSON.stringify(manifest))
		var archive_path := directory.path_join("fork.zip")
		check(ModExport.new().export_mod(manifest_path, archive_path).is_empty(), "Inherited map did not export")
		var archive := ZIPReader.new()
		check(archive.open(archive_path) == OK, "Cannot inspect inherited map ZIP")
		check(archive.get_files().size() == 2, "Inherited map export included unreferenced or original resources")
		archive.close()
		var profile := Profile.new()
		check(profile.add(manifest_path).is_empty(), "Cannot preview exported variant profile")
		runtime.content.root = directory
		prepared.maps.d00a.models = [variant]
		var preview := ProfilePreview.new()
		var composed := preview.create(runtime.content, profile, "d00a", 1)
		check(composed != null, preview.error)
		if composed != null:
			check(not composed.get_node("LocalMapReference").get_child(0).visible, "Profile preview omitted resolved removals")
			composed.free()
		fork.free()
	prepared.stageDirSha256 = "changed-stage"
	var expected := MapSource.validate(authored.get_meta("mgs_scene_source"), prepared, "s00a")
	check(not expected.is_empty(), "Editor source check accepted changed content")
	var error := runtime.change_stage("d00a")
	check("source.test (s00a): " + expected == error, "Runtime source mismatch disagrees with editor or omits mod/target")
	check(runtime.stage_override == null, "Rejected source retained its authored overlay")
	authored.free()
	runtime.free()

func removal_variants() -> void:
	var variant := ASSET.replace("s00a", "d00a")
	var catalog := {ASSET:{"kind":"model", "sha256":"source"}, variant:{"kind":"model", "sha256":"different"}}
	var overlay := Node3D.new()
	overlay.set_meta("mgs_removals", [{"asset":ASSET, "anchor":Vector3.ZERO}, {"asset":ASSET, "part":0}])
	var removals := Removals.new()
	check(removals.configure(overlay, catalog, "d00a").is_empty(), "Valid variant removals were rejected")
	check(removals.rules[0].asset == variant, "Whole-model visibility required identical variant geometry")
	check(removals.rules[1].asset == ASSET, "Part hide crossed incompatible variant geometry")
	check(Registry.variant_asset(catalog, ASSET, "d00a") == ASSET, "Replacement inheritance accepted different geometry")
	var node := Node3D.new()
	node.position = Vector3.ONE
	removals.apply({"asset":variant, "node":node, "meshes":[], "metadata_meshes":[]}, 1)
	check(node.visible, "Inherited hide ignored its instance anchor")
	check(Registry.variant_asset(catalog, ASSET, "s01a", false) == ASSET, "Whole-model hide crossed unrelated maps")
	catalog[variant].sha256 = "source"
	check(removals.configure(overlay, catalog, "d00a").is_empty(), "Matching variant removals were rejected")
	check(removals.rules[1].asset == variant, "Part hide no longer follows identical variant geometry")
	node.free()
	overlay.free()

func run() -> void:
	var directory := "user://map-composition-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	var prepared := fixture(directory)
	pbr_and_layers(directory, prepared)
	source_validation(directory, prepared)
	removal_variants()
	await process_frame
	print("MGS_MAP_COMPOSITION_TEST failures=%d" % failures)
	quit(1 if failures else 0)
