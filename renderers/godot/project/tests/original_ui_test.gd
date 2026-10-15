extends SceneTree

const Assets = preload("res://original_ui_assets.gd")
const Shape = preload("res://original_ui_shape.gd")
const Export = preload("res://addons/mgs_editor/mod_export.gd")
const ROOT = "res://.generated/original-ui-test"
const FONT = "mgs/integral-j/disc1/stage/init/font.r"
const LAYOUT = "mgs/integral-j/disc1/stage/init/layout.s"
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func write(path: String, content: String) -> void:
	var file := FileAccess.open(ROOT.path_join(path), FileAccess.WRITE)
	file.store_string(content)

func entry(identity: String, kind: String, path: String, files: Array[String]) -> Dictionary:
	var hashes := {}
	for file in files: hashes[file] = FileAccess.get_sha256(ROOT.path_join(file))
	return {"kind":kind, "path":path, "sha256":"a".repeat(64), "preparedFiles":hashes,
		"contentId":"sha256:" + (identity + "\n" + "a".repeat(64)).sha256_text(),
		"preparedRevision":JSON.stringify(hashes, "", true).sha256_text()}

func fixture() -> Dictionary:
	DirAccess.make_dir_recursive_absolute(ROOT)
	var image := Image.create(12, 5, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	check(image.save_png(ROOT.path_join("font.png")) == OK, "Cannot save UI atlas fixture")
	write("font.json", JSON.stringify({"schema":1, "texture":"font.png", "size":[12, 5], "height":5, "line_height":8,
		"glyphs":{"65":{"rect":[0, 0, 6, 5], "advance":6, "offset":0}, "73":{"rect":[6, 0, 6, 5], "advance":4, "offset":1}}}))
	write("layout.json", JSON.stringify({"schema":1, "size":[320, 224], "draw_order":[0], "shapes":[
		{"type":"polygon", "points":[[0, 0], [10, 0], [10, 10], [0, 10]], "color":[255, 64, 32], "blend":1}]}))
	return {FONT:entry(FONT, "ui_font", "font.json", ["font.json", "font.png"]), LAYOUT:entry(LAYOUT, "ui_layout", "layout.json", ["layout.json"])}

func exercise() -> void:
	var catalog := fixture()
	var assets := Assets.new()
	assets.configure(ROOT, catalog)
	var font := assets.font(FONT)
	check(font != null, "Font loading failed: " + assets.error)
	if font == null: return
	check(font.get_string_size("AIA", HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x == 16, "Original glyph advances changed")
	check(font.get_string_size("AIA", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x == 32, "Larger Godot font sizes lose original glyph metrics")
	check(font.get_height(8) == 8, "Original line spacing changed")
	check(assets.font(FONT) == font, "Repeated labels duplicate font resources")
	check(not font.allow_system_fallback, "Original UI silently substitutes system glyphs")
	var shape := Shape.new()
	shape.source_id = LAYOUT
	check(shape.bind(assets).is_empty(), "Original vector binding failed")
	shape.position = Vector2(20, 30)
	shape.self_modulate = Color(0.4, 0.7, 0.2)
	shape.line_width = 2.0
	check(shape.bind(assets).is_empty() and shape.position == Vector2(20, 30) and shape.line_width == 2.0, "Binding overwrites authored layout")
	shape.shape_index = 9
	check(not shape.bind(assets).is_empty() and shape._points.is_empty(), "Invalid shape retains old artwork")
	shape.shape_index = 0
	check(shape.bind(assets).is_empty(), "Cannot rebind shape")
	var packed := PackedScene.new()
	check(packed.pack(shape) == OK and ResourceSaver.save(packed, ROOT.path_join("shape.tscn")) == OK, "Cannot save original UI reference")
	shape.free()
	var saved := FileAccess.get_file_as_string(ROOT.path_join("shape.tscn"))
	check("source_id" in saved and not "PackedVector2Array" in saved and not "layout.json" in saved, "Scene embeds original vector data")
	check(ResourceSaver.save(font, ROOT.path_join("retail-font.tres")) == OK, "Cannot exercise unsafe font serialization")
	var exporter := Export.new()
	exporter.root = ProjectSettings.globalize_path(ROOT)
	exporter.collect(ROOT.path_join("retail-font.tres"))
	check(not exporter.error.is_empty(), "Serialized retail font can enter a mod export")
	check(assets.font("missing") == null and "not prepared" in assets.error, "Missing UI uses a silent fallback")
	catalog[FONT].preparedFiles.erase("font.png")
	catalog[FONT].preparedRevision = JSON.stringify(catalog[FONT].preparedFiles, "", true).sha256_text()
	assets.configure(ROOT, catalog)
	check(assets.font(FONT) == null and "texture dependency" in assets.error, "Font accepted an untracked atlas")
	catalog = fixture()
	write("font.png", "changed")
	assets.configure(ROOT, catalog)
	check(assets.font(FONT) == null and "missing or changed" in assets.error, "Changed UI texture accepted")
	catalog = fixture()
	var malformed = JSON.parse_string(FileAccess.get_file_as_string(ROOT.path_join("font.json")))
	malformed.glyphs["65"].rect = [0, 0, 5000, 1]
	write("font.json", JSON.stringify(malformed))
	catalog[FONT] = entry(FONT, "ui_font", "font.json", ["font.json", "font.png"])
	assets.configure(ROOT, catalog)
	check(assets.font(FONT) == null and "invalid glyph metrics" in assets.error, "Out-of-atlas glyph accepted")

func _initialize() -> void:
	exercise()
	var args := OS.get_cmdline_user_args()
	if args.size() == 1:
		var catalog = JSON.parse_string(FileAccess.get_file_as_string(args[0].path_join("catalog.json")))
		var assets := Assets.new()
		assets.configure(args[0], catalog.assets)
		var count := 0
		for identity in catalog.assets:
			if catalog.assets[identity].kind == "ui_font":
				check(assets.font(identity) != null, "Disc font rejected: " + assets.error)
				count += 1
			elif catalog.assets[identity].kind == "ui_layout":
				check(not assets.layout(identity).is_empty(), "Disc layout rejected: " + assets.error)
				count += 1
		check(count == 9, "Expected nine original UI assets including the subtitle font")
		print("MGS_ORIGINAL_UI_DISC disc=%d assets=%d" % [catalog.disc, count])
	print("MGS_ORIGINAL_UI_TEST failures=%d" % failures)
	quit(0 if failures == 0 else 1)
