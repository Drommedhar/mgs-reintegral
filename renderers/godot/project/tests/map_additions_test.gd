extends SceneTree

const Registry = preload("res://mod_registry.gd")
const Composition = preload("res://map_composition.gd")
const Content = preload("res://content_catalog.gd")
const Coordinates = preload("res://map_coordinates.gd")
const Templates = preload("res://event_light_templates.gd")
const EventLights = preload("res://event_lights.gd")
const MapEnvironment = preload("res://map_environment.gd")
const ModExport = preload("res://addons/mgs_editor/mod_export.gd")
const ASSET = "mgs/integral-j/disc1/stage/s00a/0001.k"
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	run.call_deferred()

func write_manifest(directory: String, manifest: Dictionary) -> String:
	var path := directory.path_join("mod.json")
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(manifest))
	return path

func save_overlay(directory: String, energy: float, editor: bool) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	FileAccess.open(directory.path_join("behavior.gd"), FileAccess.WRITE).store_string(FileAccess.get_file_as_string("res://tests/map_additions_fixture.gd"))
	var overlay := Node3D.new()
	overlay.name = "AuthoredRoot"
	overlay.set_script(load(directory.path_join("behavior.gd")))
	overlay.activated.connect(overlay.receive, CONNECT_PERSIST)
	if editor: Coordinates.mark_editor(overlay)
	overlay.position = Vector3(0, 1, 2) if editor else Vector3(0, -1, -2)
	var marker := MeshInstance3D.new()
	marker.name = "Marker"
	marker.mesh = BoxMesh.new()
	marker.position = Vector3(1, 2, 3) if editor else Vector3(1, -2, -3)
	overlay.add_child(marker)
	marker.owner = overlay
	var top_level := Node3D.new()
	top_level.name = "TopLevel"
	top_level.top_level = true
	top_level.position = Vector3(4, 5, 6) if editor else Vector3(4, -5, -6)
	marker.add_child(top_level)
	top_level.owner = overlay
	var environment := MapEnvironment.attach(overlay)
	environment.environment.ambient_light_energy = energy
	Templates.attach(overlay)
	overlay.get_node("EventLightTemplates/TemporaryFlash").light_energy = energy
	var light_edits := {"lamp":{"light_energy":energy}}
	if energy == 2.0: light_edits.lamp.light_color = Color.CYAN
	overlay.set_meta("mgs_light_overrides", light_edits)
	overlay.set_meta("mgs_camera_edits", {"shared.clip":{"fixture":energy}, str(energy) + ".clip":{"fixture":energy}})
	overlay.set_meta("mgs_removals", [{"asset":ASSET}])
	var packed := PackedScene.new()
	check(packed.pack(overlay) == OK, "Cannot pack additive scene")
	check(ResourceSaver.save(packed, directory.path_join("map.tscn")) == OK, "Cannot save additive scene")
	overlay.free()

func layer_nodes(composed: Node3D) -> Array[Node]:
	return composed.find_children("AuthoredRoot", "Node3D", true, false)

func composition_checks(registry: RefCounted, content: RefCounted) -> void:
	var loader := Composition.new()
	var map := loader.load_stage(registry, content, "d00a", 1)
	check(map != null, loader.error)
	if map == null: return
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	root.add_child(viewport)
	Coordinates.to_runtime(map)
	viewport.add_child(map)
	check(map.get_meta("mgs_stage_contributors") == [{"mod":"shared-a", "source":"s00a"}, {"mod":"shared-b", "source":"s00a"}, {"mod":"exact", "source":"disc1/d00a"}], "Scope/priority ordering dropped or reordered additions")
	check(layer_nodes(map).size() == 3, "Independent scenes were discarded")
	for node in layer_nodes(map):
		check(node.get("marker") == node.get_node("Marker") and node.get("received") == 7, "Relative paths or saved signal connections broke")
		check(node.get_node("Marker").global_position.is_equal_approx(Vector3(1, -3, -5)), "Mixed legacy/editor coordinates moved an addition")
		check(node.get_node("Marker/TopLevel").global_position.is_equal_approx(Vector3(4, -5, -6)), "Top-level transform converted more than once")
		check(not node.get_node("EventLightTemplates").visible, "An inactive event template illuminates the map")
	var environment := MapEnvironment.find_in(map)
	check(is_equal_approx(environment.environment.ambient_light_energy, 3.0), "Shared priority overrode exact-scenario environment")
	check(viewport.find_world_3d().environment == environment.environment, "Godot world uses a different environment from the composition resolver")
	check(is_equal_approx(map.get_meta("mgs_light_overrides").lamp.light_energy, 3.0), "Original-light property did not resolve by scope")
	check(map.get_meta("mgs_light_overrides").lamp.light_color == Color.CYAN, "Independent original-light property was discarded")
	var edits: Dictionary = map.get_meta("mgs_camera_edits")
	check(edits.size() == 4 and edits["shared.clip"].fixture == 3.0, "Camera clip selection lost independent clips")
	var rules: Array = map.get_meta("mgs_removals")
	check(rules.size() == 1 and rules[0].asset == ASSET.replace("s00a", "d00a"), "Removals were not unioned/remapped by model hash")
	check(loader.diagnostics.size() == 5 and "exact (disc1/d00a)" in loader.diagnostics[0], "Competing settings lack the final scope/mod winner")
	var events := EventLights.new()
	viewport.add_child(events)
	check(events.configure(map).is_empty(), "Nested event templates did not load")
	check(is_equal_approx(events.templates.get_node("TemporaryFlash").light_energy, 3.0), "Event template priority differs from composition")
	viewport.free()

func variant_and_reset_checks(registry: RefCounted, content: RefCounted, paths: Array) -> void:
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(paths[0]))
	manifest.stages["d00a"] = {"scene":"map.tscn"}
	write_manifest(str(paths[0]).get_base_dir(), manifest)
	check(registry.configure(content.assets, paths).is_empty(), "Cannot load independent direct variant")
	var layers: Array = registry.stage_layers("d00a", 1)
	check(layers.size() == 3 and layers[1].mod == "shared-a" and layers[1].source == "d00a", "An explicit per-mod snapshot duplicated its inherited scene")
	check(registry.stage_layers("d00a", 2).size() == 2, "Disc1-only scene leaked into disc2")
	check(registry.configure(content.assets, [paths[0]]).is_empty(), "Cannot disable additive layers")
	var loader := Composition.new()
	var single := loader.load_stage(registry, content, "d00a", 1)
	check(single != null and single.has_node("Marker") and loader.diagnostics.is_empty(), "Single-layer compatibility or reset retained composite state")
	if single != null: single.free()

func export_checks(paths: Array) -> void:
	for path in paths:
		var archive_path := str(path).get_base_dir().path_join("mod.zip")
		check(ModExport.new().export_mod(path, archive_path).is_empty(), "Independent mod did not export")
		var archive := ZIPReader.new()
		check(archive.open(archive_path) == OK, "Cannot read additive mod ZIP")
		var files := Array(archive.get_files()).filter(func(file): return not str(file).ends_with("/"))
		files.sort()
		check(files == ["behavior.gd", "map.tscn", "mod.json"], "Export contains original assets or another mod's files")
		archive.close()

func rejected_layer_check(registry: RefCounted, content: RefCounted, paths: Array) -> void:
	var path: String = str(paths[1]).get_base_dir().path_join("map.tscn")
	var packed := load(path) as PackedScene
	var node := packed.instantiate() as Node3D
	node.set_meta("mgs_scene_source", {"stage":"s00a", "stage_dir_sha256":"changed"})
	check(packed.pack(node) == OK and ResourceSaver.save(packed, path) == OK, "Cannot write source mismatch fixture")
	node.free()
	check(registry.configure(content.assets, paths).is_empty(), "Cannot configure mismatch fixture")
	var loader := Composition.new()
	var map := loader.load_stage(registry, content, "d00a", 1)
	check(map == null and loader.error.begins_with("shared-b (s00a):"), "A lower-priority invalid contribution was silently omitted")
	if map != null: map.free()

func run() -> void:
	var directory := "user://map-additions-%d" % Time.get_ticks_usec()
	var paths: Array = []
	var definitions := [{"id":"shared-a", "priority":100, "target":"s00a"}, {"id":"shared-b", "priority":200, "target":"s00a"}, {"id":"exact", "priority":1, "target":"disc1/d00a"}]
	for index in definitions.size():
		var definition: Dictionary = definitions[index]
		var folder := directory.path_join(definition.id)
		save_overlay(folder, index + 1.0, index != 0)
		paths.append(write_manifest(folder, {"schema":1, "id":definition.id, "priority":definition.priority, "stages":{definition.target:{"scene":"map.tscn"}}}))
	var content := Content.new()
	content.catalogs[1] = {"disc":1, "stageDirSha256":"original", "maps":{"s00a":{}, "d00a":{}}}
	content.assets = {ASSET:{"kind":"model", "sha256":"same-model"}, ASSET.replace("s00a", "d00a"):{"kind":"model", "sha256":"same-model"}}
	var registry := Registry.new()
	check(registry.configure(content.assets, [paths[2], paths[1], paths[0]]).is_empty(), "Cannot configure additive mods")
	composition_checks(registry, content)
	variant_and_reset_checks(registry, content, paths)
	export_checks(paths)
	rejected_layer_check(registry, content, paths)
	await process_frame
	print("MGS_MAP_ADDITIONS_TEST failures=%d" % failures)
	quit(1 if failures else 0)
