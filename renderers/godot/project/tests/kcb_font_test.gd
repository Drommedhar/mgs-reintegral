extends SceneTree

const Assets = preload("res://original_ui_assets.gd")
const Kcb = preload("res://original_kcb_font.gd")
const Fixture = preload("res://tests/original_ui_test.gd")
const Export = preload("res://addons/mgs_editor/mod_export.gd")
const ID := "mgs/integral-j/disc1/stage/init/ca68.r"
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func fixture_document() -> Dictionary:
	var glyphs := {}
	var codes: Array[int] = []
	for code in range(32, 128): codes.append(code)
	codes.append(Kcb.GLYPH_BASE + 1)
	codes.append(Kcb.DASH_CODE)
	for index in codes.size():
		var width := 18 if codes[index] == Kcb.DASH_CODE else 12
		glyphs[str(codes[index])] = {"rect":[index % 32 * 20 + 1, index / 32 * 16 + 1, width, 12],
			"advance":width, "offset":0, "offset_y":1 if codes[index] == Kcb.GLYPH_BASE + 1 else 0}
	return {"schema":1, "format":"kcb", "texture":"kcb.png", "size":[640, 64], "font_size":12,
		"height":12, "line_height":18, "bank_length":1, "glyphs":glyphs}

func load_fixture(fixture: SceneTree, document: Dictionary) -> RefCounted:
	fixture.write("kcb.json", JSON.stringify(document))
	var assets := Assets.new()
	var files: Array[String] = ["kcb.json", "kcb.png"]
	assets.configure(Fixture.ROOT, {ID:fixture.entry(ID, "ui_font", "kcb.json", files)})
	return assets

func fixture_assets() -> RefCounted:
	var fixture := Fixture.new()
	DirAccess.make_dir_recursive_absolute(Fixture.ROOT)
	var image := Image.create(640, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	check(image.save_png(Fixture.ROOT.path_join("kcb.png")) == OK, "Cannot save KCB fixture")
	var assets := load_fixture(fixture, fixture_document())
	fixture.free()
	return assets

func exercise() -> void:
	var fixture := Fixture.new()
	var document := fixture_document()
	var assets := fixture_assets()
	var font: FontFile = assets.font("mgs/ui/subtitle")
	check(font != null, "KCB fixture rejected: " + assets.error)
	if font != null:
		check(font.get_string_size("AB", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x == 24, "KCB advances changed")
		check(font.get_height(12) == 18 and font.get_height(24) == 36, "KCB line spacing does not scale")
		check(font.get_string_size(String.chr(Kcb.GLYPH_BASE + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x == 12, "Native bank glyph cannot be addressed")
		check(not font.allow_system_fallback, "KCB uses a system font fallback")
		check(ResourceSaver.save(font, Fixture.ROOT.path_join("kcb-retail.tres")) == OK, "Cannot save KCB serialization fixture")
		var exporter := Export.new()
		exporter.root = ProjectSettings.globalize_path(Fixture.ROOT)
		exporter.collect(Fixture.ROOT.path_join("kcb-retail.tres"))
		check(not exporter.error.is_empty(), "Original subtitle glyphs can enter mod ZIP")
	for kind in ["bank_length", "missing", "offset", "width", "position", "format"]:
		var broken := document.duplicate(true)
		match kind:
			"bank_length": broken.bank_length = 0
			"missing": broken.glyphs.erase("65")
			"offset": broken.glyphs["65"].offset_y = 3
			"width": broken.glyphs["65"].advance = 20
			"position": broken.glyphs["65"].rect[0] += 1
			"format": broken.format = "unknown"
		assets = load_fixture(fixture, broken)
		check(assets.font(ID) == null and not assets.error.is_empty(), "Malformed KCB accepted: " + kind)
	fixture.free()

func _initialize() -> void:
	exercise()
	for directory in OS.get_cmdline_user_args():
		var catalog = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("catalog.json")))
		var assets := Assets.new()
		assets.configure(directory, catalog.assets, int(catalog.disc))
		var font := assets.font("mgs/ui/subtitle")
		check(font != null, "Original subtitle font failed: " + assets.error)
		if font != null:
			var document := assets.document("mgs/ui/subtitle", "ui_font")
			var advance := 0
			for code in "Snake, do you read me?".to_utf32_buffer().to_int32_array(): advance += int(document.glyphs[str(code)].advance)
			check(font.get_string_size("Snake, do you read me?", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x == advance, "Original subtitle advances changed")
			check(font.get_glyph_list(0, Vector2i(12, 0)).size() == 538, "Original subtitle glyphs missing")
	print("MGS_KCB_FONT_TEST failures=%d" % failures)
	quit(0 if failures == 0 else 1)
