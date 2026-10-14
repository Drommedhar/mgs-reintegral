extends SceneTree

const State = preload("res://goggles_state.gd")
const Assets = preload("res://original_ui_assets.gd")
const Authoring = preload("res://addons/mgs_editor/ui_authoring.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func packet(mode: int = 1, flags: int = 7) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(68)
	for entry in [[0, 1], [4, 3], [8, mode], [12, flags], [16, 4095], [20, 12], [24, 7]]: bytes.encode_u32(entry[0], entry[1])
	bytes.encode_s32(36, -12)
	bytes.encode_s32(40, 20)
	for index in range(52, 68): bytes[index] = 1
	return bytes

func state_checks() -> void:
	var state := State.new()
	state.session_id = PackedByteArray()
	state.session_id.resize(16)
	state.session_id.fill(1)
	var bytes := packet()
	check(state.apply(bytes, {"epoch": 3}).is_empty(), "Valid goggles state rejected")
	check(state.current.is_empty(), "UI changed before native FRAME")
	check(state.present(3).heading == 4095 and state.current.offsets[1] == Vector2(-12, 20), "UI fields changed on presentation")
	check(state.present(4).is_empty(), "UI leaked across native epoch")
	for change in [[0, 2], [4, 2], [8, 3], [12, 8], [16, 4096], [24, 8], [36, 21], [52, 0]]:
		var malformed := bytes.duplicate()
		malformed.encode_u32(change[0], change[1])
		check(not state.apply(malformed, {"epoch": 3}).is_empty(), "Malformed UI accepted at offset %d" % change[0])
	check(not state.apply(bytes.slice(0, 67), {"epoch": 3}).is_empty(), "Short UI packet accepted")
	check(not state.apply(packet(0, 0), {"epoch": 3}).is_empty(), "Inactive UI with heading accepted")

func load_assets() -> Dictionary:
	var arguments := Array(OS.get_cmdline_user_args()).filter(func(argument): return not argument.begins_with("--"))
	if not arguments.is_empty():
		var directory: String = arguments[0]
		var catalog = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("catalog.json")))
		return {"root": directory, "assets": catalog.assets, "disc": int(catalog.disc)}
	var fixture := preload("res://tests/original_ui_test.gd").new()
	var source: Dictionary = fixture.fixture()
	check(fixture.failures == 0, "Cannot create original UI fixture")
	var catalog := {}
	for filename in Assets.SHARED.values():
		var identity: String = "mgs/integral-j/disc1/stage/init/" + filename
		catalog[identity] = source[fixture.FONT if filename.ends_with(".r") else fixture.LAYOUT].duplicate(true)
		catalog[identity].contentId = "sha256:" + (identity + "\n" + "a".repeat(64)).sha256_text()
	var directory: String = fixture.ROOT
	fixture.free()
	return {"root": directory, "assets": catalog, "disc": 1}

func run() -> void:
	state_checks()
	var originals := load_assets()
	var workspace := preload("res://addons/mgs_editor/mod_workspace.gd").new()
	workspace.root = "user://goggles-ui-%d" % Time.get_ticks_usec()
	var authoring := Authoring.new()
	var path := authoring.open_goggles(workspace, originals.root, originals.assets, originals.disc)
	check(not path.is_empty(), "Cannot author UI: " + authoring.error)
	if path.is_empty():
		quit(1)
		return
	var scene := load(path).instantiate() as Control
	root.add_child(scene)
	var session := authoring.attach(scene, originals.root, originals.assets, originals.disc)
	check(authoring.error.is_empty(), "Cannot attach local artwork: " + authoring.error)
	var scan := scene.get_node("NightVision/Indicators/Scan") as Label
	var vector := scene.get_node("NightVision/Indicators/Vector0") as Label
	check(scan.get_theme_font("font").get_meta("mgs_retail_derived", false), "Original font missing from preview")
	check(scan.position == Vector2(41, 42), "Original SCAN layout changed")
	check(scene.get_node("NightVision/Indicators/Mode").position == Vector2(137, 42), "Original MODE layout changed")
	var state := State.new()
	state.session_id.resize(16)
	state.session_id.fill(1)
	check(state.apply(packet(), {"epoch": 3}).is_empty(), "Cannot parse active UI")
	scene.call("apply_native_state", state.present(3))
	check(vector.text == "16376", "Native heading vector differs")
	check(scene.get_node("NightVision/SightLayer1").position == Vector2(-12, 20), "Native sight movement lost")
	check(scene.get_node("NightVision").visible and not scene.get_node("ThermalVision").visible, "Wrong goggles mode")
	scene.set("preview_mode", 2)
	scene.set("preview_heading", 321)
	scene.call("update_preview")
	check(scene.get_node("ThermalVision").visible and not scene.get_node("NightVision").visible, "Editor cannot preview thermal UI")
	scene.set("preview_mode", 1)
	scene.call("update_preview")
	scan.position += Vector2(11, 3)
	scan.add_theme_color_override("font_color", Color.BLUE)
	vector.position += Vector2(2, 1)
	session.prepare_save()
	check(not scan.has_theme_font_override("font"), "Original font still serializable during save")
	check(vector.text == "0" and vector.position == Vector2(42, 57), "Preview state overwrote authored layout")
	check(scene.get_node("NightVision/SightLayer1").position == Vector2.ZERO, "Runtime offset leaked into scene")
	var packed := PackedScene.new()
	check(packed.pack(scene) == OK and ResourceSaver.save(packed, path) == OK, "Cannot save editable UI")
	session.finish_save()
	check(scan.position == Vector2(52, 45), "Layout edit lost while restoring preview")
	check(authoring.open_goggles(workspace, originals.root, originals.assets, originals.disc) == path, "Reopening created a new scene")
	var exporter := preload("res://addons/mgs_editor/mod_export.gd").new()
	var archive: String = workspace.root.path_join("goggles.zip")
	check(exporter.export_mod(workspace.root.path_join("mod.json"), archive).is_empty(), "UI ZIP export failed: " + exporter.error)
	var zip := ZIPReader.new()
	check(zip.open(archive) == OK, "Cannot open UI ZIP")
	var files := Array(zip.get_files()).filter(func(file): return not file.ends_with("/"))
	check(files.size() == 4, "UI ZIP contains unexpected dependencies: " + str(files))
	var installed: String = workspace.root.path_join("installed")
	for file in files:
		check(file.get_extension() in ["json", "gd", "tscn"], "Original binary shipped in UI ZIP")
		var destination := installed.path_join(str(file))
		DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
		FileAccess.open(destination, FileAccess.WRITE).store_buffer(zip.read_file(file))
	zip.close()
	var registry := preload("res://mod_registry.gd").new()
	check(registry.configure({}, [installed.path_join("mod.json")]).is_empty(), "Reopened UI mod rejected")
	var presenter := preload("res://goggles_presenter.gd").new()
	root.add_child(presenter)
	check(presenter.initialize(registry.ui, originals.root, originals.assets, originals.disc).is_empty(), "Cannot load exported goggles UI")
	check(presenter.ui.get_node("NightVision/Indicators/Scan").position == Vector2(52, 45), "ZIP lost custom layout")
	check(presenter.ui.get_node("NightVision/Indicators/Scan").get_theme_color("font_color") == Color.BLUE, "ZIP lost custom color")
	presenter.ui.call("detach_originals")
	var custom_theme := Theme.new()
	var custom_font := SystemFont.new()
	custom_theme.set_font("font", "Label", custom_font)
	presenter.ui.theme = custom_theme
	check(presenter.bind_originals().is_empty(), "Cannot bind UI with an authored theme")
	check(presenter.ui.get_node("NightVision/Indicators/Scan").get_theme_font("font") == custom_font, "Original font replaced the authored Godot theme")
	presenter.state.session_id = state.session_id
	presenter.state.apply(packet(2), {"epoch": 3})
	presenter.present(3, true)
	check(presenter.visible and presenter.ui.get_node("ThermalVision").visible, "Imported UI cannot render thermal state")
	presenter.present(3, false)
	check(not presenter.visible, "Disabled native display left goggles visible")
	presenter.free()
	scene.free()
	print("MGS_GOGGLES_UI_TEST failures=%d" % failures)
	quit(1 if failures else 0)
