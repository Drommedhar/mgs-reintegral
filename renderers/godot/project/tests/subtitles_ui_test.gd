extends SceneTree

const State = preload("res://subtitles_state.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func packet() -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(208)
	for pair in [[0, 1], [4, 3], [8, 1], [12, 1], [32, 1], [36, 1], [44, 3], [48, 100], [52, 190], [56, 256], [60, 20], [64, 6], [72, 6], [76, 256], [80, 38], [84, 1], [88, 80], [128, 1], [132, 65], [140, 6], [144, 6], [148, 12], [156, 18]]:
		bytes.encode_u32(pair[0], pair[1])
	for index in range(16, 32): bytes[index] = 7
	for index in 3: bytes.encode_u16(98 + index * 2, [0x2108, 0x4210, 0x6739][index])
	for index in range(160, 178): bytes[index] = 0x1b
	return bytes

func reference_frame(bytes: PackedByteArray) -> PackedByteArray:
	var result := bytes.slice(0, 128)
	result.encode_u32(12, 0)
	for index in range(76, 88, 4): result.encode_u32(index, 0)
	for index in range(96, 128): result[index] = 0
	return result

func state_checks() -> State:
	var state := State.new()
	state.session_id.resize(16)
	state.session_id.fill(7)
	var bytes := packet()
	var reference := reference_frame(bytes)
	check(not state.apply(reference, {"epoch": 3}).is_empty(), "Undefined page accepted")
	check(state.apply(bytes, {"epoch": 3}).is_empty(), "Subtitle layout rejected")
	check(state.current.is_empty(), "Subtitle appeared before native FRAME")
	check(state.present(3).layout.glyphs[0].code == 65, "Glyph identity lost")
	check(state.apply(reference, {"epoch": 3}).is_empty(), "Retained page rejected")
	check(state.present(3).layout.glyphs.size() == 1, "Retained font bank lost")
	for change in [[0, 2], [4, 4], [12, 2], [16, 0], [32, 2], [36, 2], [40, 3], [56, 257], [76, 257], [80, 129], [84, 4097], [88, 79], [92, 1], [128, 7], [132, 0], [144, 21], [148, 13], [152, 4], [156, 49]]:
		var malformed := bytes.duplicate()
		malformed.encode_u32(change[0], change[1])
		check(not state.apply(malformed, {"epoch": 3}).is_empty(), "Malformed subtitle accepted: " + str(change))
	check(not state.apply(bytes.slice(0, 207), {"epoch": 3}).is_empty(), "Truncated subtitle accepted")
	check(state.present(4).is_empty(), "Subtitle survived epoch change")
	reference.encode_u32(4, 4)
	check(not state.apply(reference, {"epoch": 4}).is_empty(), "Old epoch font bank reused")
	state.present(3)
	return state

func run() -> void:
	var state := state_checks()
	var fixture := preload("res://tests/goggles_ui_test.gd").new()
	var originals: Dictionary = fixture.load_assets()
	var workspace := preload("res://addons/mgs_editor/mod_workspace.gd").new()
	workspace.root = "user://subtitles-ui-%d" % Time.get_ticks_usec()
	var authoring := preload("res://addons/mgs_editor/ui_authoring.gd").new()
	var path: String = authoring.open_ui(workspace, originals.root, originals.assets, originals.disc, "subtitles")
	check(not path.is_empty(), "Cannot create subtitle UI: " + authoring.error)
	if path.is_empty():
		fixture.free()
		quit(1)
		return
	var scene := load(path).instantiate() as Control
	root.add_child(scene)
	var session: Node = authoring.attach(scene, originals.root, originals.assets, originals.disc)
	check(authoring.error.is_empty(), "Cannot preview subtitles: " + authoring.error)
	var text: Control = scene.get_node("Text")
	text.position = Vector2(6, -10)
	text.font_color = Color.GREEN
	var pause_font := SystemFont.new()
	pause_font.font_names = PackedStringArray(["Arial"])
	scene.get_node("Pause").add_theme_font_override("font", pause_font)
	scene.apply_native_state(state.current)
	check(text._font != null and text._active, "Native glyph font missing")
	var original: FontFile = text._font
	var next := reference_frame(packet())
	next.encode_u32(44, 2)
	state.apply(next, {"epoch": 3})
	scene.apply_native_state(state.present(3))
	check(text._font == original, "Font rebuilt for a timer-only update")
	next.encode_u32(36, 0)
	state.apply(next, {"epoch": 3})
	scene.apply_native_state(state.present(3))
	check(not text._active, "Caption-off ignored")
	next.encode_u32(40, 1)
	next.encode_u32(36, 1)
	state.apply(next, {"epoch": 3})
	scene.apply_native_state(state.present(3))
	check(scene.get_node("Pause").visible and scene.get_node("Dim").visible, "Modal caption missing pause/dim")
	session.prepare_save()
	check(text._font == null and text.preview_font == null and text._layout.is_empty(), "Original page survived save preparation")
	check(scene.get_node("Pause").get_theme_font("font") == pause_font, "Authored PAUSE font removed during save")
	var packed := PackedScene.new()
	check(packed.pack(scene) == OK and ResourceSaver.save(packed, path) == OK, "Cannot save subtitle scene")
	session.finish_save()
	var exporter := preload("res://addons/mgs_editor/mod_export.gd").new()
	var archive: String = workspace.root.path_join("subtitles.zip")
	check(exporter.export_mod(workspace.root.path_join("mod.json"), archive).is_empty(), "Subtitle export failed: " + exporter.error)
	var zip := ZIPReader.new()
	check(zip.open(archive) == OK, "Cannot open subtitle ZIP")
	var installed: String = workspace.root.path_join("installed")
	var files := Array(zip.get_files()).filter(func(file): return not file.ends_with("/"))
	check(files.size() == 5, "Unexpected subtitle ZIP files: " + str(files))
	for file in files:
		check(file.get_extension() in ["gd", "tscn", "json"], "Retail glyphs leaked into mod")
		var destination := installed.path_join(str(file))
		DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
		FileAccess.open(destination, FileAccess.WRITE).store_buffer(zip.read_file(file))
	zip.close()
	var registry := preload("res://mod_registry.gd").new()
	check(registry.configure({}, [installed.path_join("mod.json")]).is_empty(), "Relocated subtitle mod rejected")
	var presenter := preload("res://subtitles_presenter.gd").new()
	root.add_child(presenter)
	check(presenter.initialize(registry.ui, originals.root, originals.assets, originals.disc).is_empty(), "Cannot initialize relocated subtitles")
	presenter.state.session_id = state.session_id
	check(presenter.state.apply(packet(), {"epoch": 3}).is_empty(), "Cannot apply relocated subtitles")
	presenter.present(3, true)
	check(presenter.visible and presenter.ui.get_node("Text").font_color == Color.GREEN, "Custom subtitle color lost")
	check(presenter.ui.get_node("Text").position == Vector2(6, -10), "Native position overwrote authored offset")
	check(presenter.ui.get_node("Pause").get_theme_font("font") is SystemFont, "Original font replaced authored PAUSE font after ZIP reopen")
	presenter.present(4, true)
	check(not presenter.visible, "Old epoch UI survived")
	presenter.free()
	scene.free()
	fixture.free()
	print("MGS_SUBTITLES_UI_TEST failures=%d" % failures)
	quit(1 if failures else 0)
