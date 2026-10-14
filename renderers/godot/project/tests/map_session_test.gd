extends SceneTree

const Authoring = preload("res://addons/mgs_editor/map_authoring.gd")
const MapLights = preload("res://map_lights.gd")
const Coordinates = preload("res://map_coordinates.gd")
const SceneView = preload("res://scene_view.gd")
const ModExport = preload("res://addons/mgs_editor/mod_export.gd")
const ASSET = "mgs/integral-j/disc1/stage/s00a/1234.k"
const LAYOUT = {"lights": [{"id": "1234.l/000", "position": [1000, 2000, 3000], "radius": 2000, "extent": 3000, "color": [80, 180, 130]}]}
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func fixture() -> Node3D:
	var reference := Node3D.new()
	var actor := Node3D.new()
	actor.name = "s00a_1234_k"
	actor.set_meta("mgs_asset_id", ASSET)
	reference.add_child(actor)
	for index in 2:
		var mesh := MeshInstance3D.new()
		mesh.name = "mesh_%03d" % index
		mesh.mesh = BoxMesh.new()
		actor.add_child(mesh)
	return reference

func save(overlay: Node3D, path: String) -> void:
	overlay.propagate_notification(Node.NOTIFICATION_EDITOR_PRE_SAVE)
	overlay.get_node("_MapSession").prepare_save()
	var packed := PackedScene.new()
	check(packed.pack(overlay) == OK and ResourceSaver.save(packed, path) == OK, "Cannot save native editor fixture")
	overlay.propagate_notification(Node.NOTIFICATION_EDITOR_POST_SAVE)
	overlay.get_node("_MapSession").finish_save()

func native_edits(overlay: Node3D, path: String) -> void:
	var actor := overlay.get_node("LocalMapReference/s00a_1234_k")
	var part: Node3D = actor.get_node("mesh_000")
	check(actor.owner == overlay and part.owner == overlay, "Original model/part is hidden from the Scene tree")
	part.hide()
	var light: OmniLight3D = overlay.get_node("OriginalLights/1234_l_000")
	check(light.owner == overlay and light.position == Vector3(1, 2, 3), "Original light is missing or inverted")
	check(light.omni_range == 3.0 and light.shadow_enabled, "Original light range or shadows are missing")
	light.position = Vector3(4, 5, 6)
	light.light_energy = 2.25
	light.light_color = Color(0.2, 0.4, 0.7)
	light.shadow_bias = 0.42
	var custom := OmniLight3D.new()
	custom.name = "UserLight"
	custom.position = Vector3(5, 6, 7)
	actor.add_child(custom)
	custom.owner = overlay
	var original_position := custom.global_position
	save(overlay, path)
	check(part.owner == overlay and custom.get_parent() == actor, "Saving changed the editor hierarchy")
	check(custom.global_position.is_equal_approx(original_position), "Saving moved a nested authored node")
	check(overlay.get_meta("mgs_removals").size() == 1 and overlay.get_meta("mgs_removals")[0].part == 0, "Scene-tree visibility was not saved as a visual removal")
	var overrides: Dictionary = overlay.get_meta("mgs_light_overrides")
	check(overrides["1234.l/000"].size() == 4, "Light edit serialized original defaults")
	check(is_equal_approx(overrides["1234.l/000"].shadow_bias, 0.42), "Native shadow Inspector property was not saved")
	check(overrides["1234.l/000"].position == Vector3(4, 5, 6), "Original light position edit was lost")
	var text := FileAccess.get_file_as_string(path)
	check(not "mgs_asset_id" in text and not "mgs_light_defaults" in text and not "BoxMesh" in text and not "_MapSession" in text, "Original map data leaked into the saved mod")
	part.show()
	actor.remove_child(part)
	save(overlay, path)
	check(overlay.get_meta("mgs_removals").size() == 1, "Deleting an original part was not recorded")
	actor.add_child(part)
	save(overlay, path)
	check(overlay.get_meta("mgs_removals").is_empty(), "Undoing removal did not restore the original")
	var lights := light.get_parent()
	lights.remove_child(light)
	save(overlay, path)
	check(overlay.get_meta("mgs_light_overrides")["1234.l/000"].visible == false, "Deleting an original light was not recorded")
	lights.add_child(light)
	save(overlay, path)
	check(not overlay.get_meta("mgs_light_overrides")["1234.l/000"].has("visible"), "Undoing light deletion did not restore it")

func run() -> void:
	var directory := "user://map-session-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join("stage.tscn")
	var overlay := Node3D.new()
	Coordinates.mark_editor(overlay)
	root.add_child(overlay)
	Authoring.new().attach_reference(overlay, fixture(), LAYOUT)
	var environment: Environment = overlay.get_node("MapEnvironment").environment
	check(environment.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR and environment.ambient_light_color == Color(0.6, 0.6, 0.6), "Imported map has no default ambient environment")
	environment.ambient_light_color = Color(0.4, 0.5, 0.7)
	environment.ambient_light_energy = 0.85
	var templates := overlay.get_node("EventLightTemplates")
	check(templates.get_node("WeaponSpot") is SpotLight3D, "Weapon light template missing from Scene tree")
	templates.get_node("WeaponSpot").spot_angle = 31.0
	native_edits(overlay, path)
	var active_rules = overlay.get_meta("mgs_removals").duplicate(true)
	var active_lights = overlay.get_meta("mgs_light_overrides").duplicate(true)
	root.remove_child(overlay)
	save(overlay, path)
	check(overlay.get_meta("mgs_removals") == active_rules, "Saving an inactive editor tab hid all original objects")
	check(overlay.get_meta("mgs_light_overrides") == active_lights, "Saving an inactive editor tab moved or hid original lights")
	root.add_child(overlay)
	var packed := load(path) as PackedScene
	var restored := packed.instantiate() as Node3D
	root.add_child(restored)
	Authoring.new().attach_reference(restored, fixture(), LAYOUT)
	check(restored.get_node("OriginalLights/1234_l_000").light_energy == 2.25, "Reopening lost original light edits")
	check(restored.find_children("*", "WorldEnvironment", true, false).size() == 1, "Reopening duplicated the authored environment")
	check(restored.get_node("MapEnvironment").environment.ambient_light_color == environment.ambient_light_color, "Reopening replaced edited ambient color")
	var runtime := SceneView.new()
	root.add_child(runtime)
	var model := fixture()
	for child in model.find_children("*", "", true, false): child.owner = model
	var model_scene := PackedScene.new()
	check(model_scene.pack(model) == OK and ResourceSaver.save(model_scene, directory.path_join("original.tscn")) == OK, "Cannot save model preparation fixture")
	model.free()
	runtime.asset_root = directory
	runtime.catalog = {ASSET: {"kind": "model", "path":"original.tscn", "colorCount":4}}
	check(runtime.materials.initialize(runtime.catalog, runtime.mods, directory).is_empty(), "Cannot initialize map fixture materials")
	runtime.map_definitions = {"s00a": LAYOUT}
	runtime.mods.stages = {"s00a": {"path": path, "mod": "test.session"}}
	check(runtime.change_stage("s00a").is_empty(), "Runtime rejected original light edits")
	check(runtime.event_lights.templates.get_node("WeaponSpot").spot_angle == 31.0, "Runtime lost authored weapon cone")
	var light := runtime.original_lights.get_node("1234_l_000")
	check(light.global_position == Vector3(4, -5, -6) and light.light_energy == 2.25, "Runtime light differs from the edited light")
	check(runtime.stage_override.get_node("UserLight").global_position == Vector3(5, 6, 7), "Runtime lost authored node parented under a reference")
	check(runtime.default_environment == null, "Runtime added a second environment over the authored one")
	check(runtime.stage_override.get_node("MapEnvironment").environment.ambient_light_color == environment.ambient_light_color, "Runtime lost authored ambient color")
	check(is_equal_approx(runtime.stage_override.get_node("MapEnvironment").environment.ambient_light_energy, 0.85), "Runtime lost authored ambient energy")
	check_cutscene(runtime, path)
	check(not MapLights.validate(LAYOUT, {"missing": {"visible": false}}).is_empty(), "Unknown light selector accepted")
	check(not MapLights.validate(LAYOUT, {"1234.l/000": {"omni_range": 0}}).is_empty(), "Invalid light override accepted")
	var manifest := {"schema": 1, "id": "test.session", "stages": {"s00a": {"scene": "stage.tscn"}}}
	FileAccess.open(directory.path_join("mod.json"), FileAccess.WRITE).store_string(JSON.stringify(manifest))
	check(ModExport.new().export_mod(directory.path_join("mod.json"), directory.path_join("mod.zip")).is_empty(), "Native editor scene could not be exported")
	var reader := ZIPReader.new()
	check(reader.open(directory.path_join("mod.zip")) == OK, "Cannot inspect exported mod")
	check(reader.get_files().size() == 2, "Original map resources were included in ZIP")
	reader.close()
	var cloned: Node = overlay.get_node("LocalMapReference/s00a_1234_k/mesh_000").duplicate()
	cloned.name = "CopiedOriginalPart"
	overlay.add_child(cloned)
	cloned.owner = overlay
	save(overlay, path)
	check(not ModExport.new().export_mod(directory.path_join("mod.json"), directory.path_join("retail-copy.zip")).is_empty(), "Duplicated original geometry could be shipped")
	runtime.free()
	restored.free()
	overlay.free()
	await process_frame
	print("MGS_MAP_SESSION_TEST failures=%d" % failures)
	quit(1 if failures else 0)

func check_cutscene(runtime: Node3D, path: String) -> void:
	runtime.map_definitions["d00a"] = LAYOUT
	runtime.mods.stages.s00a.original_lighting = false
	check(runtime.change_stage("d00a").is_empty(), "Cutscene did not inherit gameplay overlay")
	check(runtime.scene_stage == "d00a" and runtime.mods.stage_source("d00a") == "s00a", "Stage identity or override source changed")
	check(not runtime.mods.stage_definition("d00a").original_lighting, "Cutscene lost relighting selection")
	check(runtime.original_lights.get_node("1234_l_000").light_energy == 2.25, "Cutscene lost original light edits")
	check(runtime.stage_override.get_node("UserLight").global_position == Vector3(5, 6, 7), "Cutscene lost authored light")
	var variant := ASSET.replace("s00a", "d00a")
	runtime.catalog[ASSET].sha256 = "same-resource"
	runtime.catalog[variant] = runtime.catalog[ASSET].duplicate()
	runtime.stage_override.set_meta("mgs_removals", [{"asset": ASSET, "part": 0}])
	check(runtime.removals.configure(runtime.stage_override, runtime.catalog, "d00a").is_empty(), "Inherited removal rejected")
	check(runtime.removals.rules[0].asset == variant, "Removal did not follow identical cutscene model")
	runtime.catalog[variant].sha256 = "different-resource"
	runtime.removals.configure(runtime.stage_override, runtime.catalog, "d00a")
	check(runtime.removals.rules[0].asset == ASSET, "Removal aliased a different model")
	runtime.mods.stages.d00a = {"path": path, "mod": "test.cutscene", "original_lighting": true}
	check(runtime.change_stage("d00a").is_empty() and runtime.mods.stage_source("d00a") == "d00a", "Explicit cutscene override did not win")
	check(runtime.mods.stage_definition("d00a").original_lighting, "Explicit cutscene lighting did not win")
	check(runtime.mods.stage_definition("d99a").is_empty(), "Unrelated stage inherited the dock override")
	check_variant_assets(runtime, variant)

func check_variant_assets(runtime: Node3D, variant: String) -> void:
	runtime.mods.stages.s01a = {"path": "helipad", "mod": "test.helipad", "original_lighting": false}
	check(runtime.mods.stage_definition("d01a").path == "helipad", "Helipad cutscene did not inherit gameplay override")
	runtime.catalog[variant].sha256 = "same-resource"
	runtime.mods.replacements[ASSET] = {"path": "gameplay.glb"}
	runtime.mods.inherit_assets(runtime.catalog)
	check(runtime.mods.replacements[variant].path == "gameplay.glb", "Identical cutscene model did not inherit replacement")
	runtime.mods.replacements[variant] = {"path": "cutscene.glb"}
	runtime.mods.inherit_assets(runtime.catalog)
	check(runtime.mods.replacements[variant].path == "cutscene.glb", "Explicit cutscene replacement was overwritten")
	var texture := ASSET.replace(".k", ".p")
	var variant_texture := variant.replace(".k", ".p")
	runtime.catalog[texture] = {"kind": "texture", "sha256": "same-texture"}
	runtime.catalog[variant_texture] = runtime.catalog[texture].duplicate()
	runtime.mods.materials[texture] = {"roughness": 0.2}
	runtime.mods.inherit_assets(runtime.catalog)
	check(runtime.mods.materials[variant_texture].roughness == 0.2, "Cutscene did not inherit PBR edits")
