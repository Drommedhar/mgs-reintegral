extends SceneTree

const Content = preload("res://content_catalog.gd")
const Provenance = preload("res://prepared_catalog.gd")
const Registry = preload("res://mod_registry.gd")
const Materials = preload("res://reference_materials.gd")
const Export = preload("res://addons/mgs_editor/mod_export.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func fixture(directory: String, disc: int) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED if disc == 1 else Color.BLUE)
	var files := {}
	for file in ["0007.png", "0007.stp.png"]:
		check(image.save_png(directory.path_join(file)) == OK, "Cannot save fixture image")
		files[file] = FileAccess.get_sha256(directory.path_join(file))
	var identity := "mgs/integral-j/disc%d/stage/s00a/0007.p" % disc
	var source := "ab".repeat(32)
	var asset := {"kind":"texture", "path":"0007.png", "sha256":source,
		"contentId":"sha256:" + (identity + "\n" + source).sha256_text(),
		"preparedFiles":files, "preparedRevision":JSON.stringify(files, "", true).sha256_text()}
	var data := {"schema":1, "edition":"integral-j", "disc":disc, "assets":{identity:asset}, "maps":{}}
	FileAccess.open(directory.path_join("catalog.json"), FileAccess.WRITE).store_string(JSON.stringify(data))

func _initialize() -> void:
	var directory := "user://disc-content-%d" % Time.get_ticks_usec()
	var first := directory.path_join("godot-content")
	var second := directory.path_join("godot-content-disc2")
	fixture(first, 1)
	fixture(second, 2)
	var content := Content.new()
	var error := content.load_root(first)
	check(error.is_empty(), "Cannot mount both disc catalogs: " + error)
	check(content.catalogs.size() == 2 and content.assets.size() == 2, "Same-named disc assets collided")
	check(Provenance.new().validate(content.root, content.assets).is_empty(), "Mounted dependency paths no longer validate")
	check(content.for_disc(3).is_empty(), "Missing disc silently selected another catalog")
	var materials := Materials.new()
	check(materials.initialize(content.assets, Registry.new(), content.root).is_empty(), "Cannot initialize disc materials")
	materials.current_disc = 2
	var identity := materials.texture_identity("0007", "s00a", "s00a", 1)
	check(identity.contains("/disc2/") and materials.texture_for(identity, false).get_image().get_pixel(0, 0) == Color.BLUE, "Disc-2 surface used disc-1 texture")
	var registry := Registry.new()
	registry.stages = {"s00a":{}, "disc1/s00a":{}, "disc2/s00a":{}, "d00a":{}}
	check(registry.stage_source("s00a", 1) == "disc1/s00a" and registry.stage_source("s00a", 2) == "disc2/s00a", "Scoped map override resolution collided")
	check(registry.stage_source("d00a", 2) == "d00a", "Exact generic cinematic edit lost precedence")
	registry.stages.erase("d00a")
	check(registry.stage_source("d00a", 2) == "disc2/s00a", "Inheritance selected the wrong disc")
	check(not Registry.valid_target("disc3/s00a") and not Registry.valid_target("disc1/../s00a"), "Invalid scoped target accepted")
	var workspace := directory.path_join("mod")
	DirAccess.make_dir_recursive_absolute(workspace)
	var stages := {}
	for disc in [1, 2]:
		var filename := "map%d.tscn" % disc
		FileAccess.open(workspace.path_join(filename), FileAccess.WRITE).store_string('[gd_scene format=3]\n[node name="Disc%d" type="Node3D"]\n' % disc)
		stages[Registry.stage_target("s00a", disc)] = {"scene":filename}
	var manifest := workspace.path_join("mod.json")
	FileAccess.open(manifest, FileAccess.WRITE).store_string(JSON.stringify({"schema":1, "id":"test.discs", "stages":stages}))
	check(registry.configure(content.assets, [manifest]).is_empty(), "Scoped manifests failed normal registration")
	check(registry.stage_definition("s00a", 2).path.ends_with("map2.tscn"), "Second disc resolved the wrong scene file")
	var archive := directory.path_join("mod.zip")
	check(Export.new().export_mod(manifest, archive).is_empty(), "Cannot export both disc variants")
	var reader := ZIPReader.new()
	check(reader.open(archive) == OK, "Cannot reopen scoped mod ZIP")
	var exported: Dictionary = JSON.parse_string(reader.read_file("mod.json").get_string_from_utf8())
	check(exported.stages.size() == 2 and exported.stages.has("disc2/s00a"), "ZIP lost a disc-specific override")
	check(reader.get_files().size() == 3, "Original content leaked into scoped mod ZIP")
	reader.close()
	FileAccess.open(second.path_join("0007.png"), FileAccess.WRITE).store_string("changed")
	check(content.load_root(first).contains("missing or changed"), "Corrupted second-disc cache was accepted")
	print("MGS_DISC_CONTENT_TEST failures=%d" % failures)
	quit(1 if failures else 0)
