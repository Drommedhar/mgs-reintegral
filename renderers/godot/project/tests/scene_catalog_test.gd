extends SceneTree

const Catalog = preload("res://addons/mgs_editor/scene_catalog.gd")
const DiscMap = preload("res://addons/mgs_editor/disc_map.gd")
const Provenance = preload("res://prepared_catalog.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var asset_root := OS.get_environment("MGS_GODOT_TEST_ASSETS")
	if asset_root.is_empty(): asset_root = "res://../../../.local/godot-content"
	var prepared: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(asset_root.path_join("catalog.json")))
	var provenance := Provenance.new()
	check(provenance.validate(asset_root, prepared.assets).is_empty(), "Prepared file provenance failed")
	var entries := Catalog.entries(prepared, asset_root)
	var available := entries.filter(func(entry): return entry.reason.is_empty())
	check(entries.filter(func(entry): return entry.stage in prepared.maps and not entry.has("clip")).size() == prepared.maps.size(), "Prepared maps were omitted from editor selection")
	for entry in available:
		var loader := DiscMap.new()
		var map := loader.load_map(asset_root, prepared, entry.stage, "", entry.get("clip", ""))
		check(map != null, "Cannot open %s: %s" % [entry.stage, loader.error])
		if map != null: map.free()
	check(available.any(func(entry): return entry.stage == "d00a"), "Cinematic set unavailable")
	var edited := prepared.duplicate(true)
	var missing_texture_model: String = edited.maps.s00a.models[0]
	edited.assets[missing_texture_model]["unresolvedTextures"] = ["1234"]
	check(Catalog.availability(edited, asset_root, "s00a").contains("textures"), "Incomplete original texture import was not reported")
	edited = prepared.duplicate(true)
	edited.maps["s99a"] = edited.maps.s00a.duplicate(true)
	check(Catalog.entries(edited, asset_root).any(func(entry): return entry.stage == "s99a" and entry.reason.is_empty()), "Selection still depends on hardcoded map names")
	edited.maps.s99a.models.append("missing")
	check(not Catalog.availability(edited, asset_root, "s99a").is_empty(), "Unresolved map was enabled")
	var saved := Catalog.source(prepared, "s00a")
	check(Catalog.source_error(saved, prepared, "s00a").is_empty(), "Same original source rejected")
	edited.stageDirSha256 = "different"
	check(not Catalog.source_error(saved, edited, "s00a").is_empty(), "Different original source accepted")
	check(Catalog.launch_profiles("d00a")[0].stage == "title", "Cinematic set offered invalid direct launch")
	check(Catalog.launch_profiles("s00a")[0].stage == "s00a", "Dock direct profile missing")
	print("MGS_SCENE_CATALOG_TEST maps=%d failures=%d" % [available.size(), failures])
	quit(1 if failures else 0)
