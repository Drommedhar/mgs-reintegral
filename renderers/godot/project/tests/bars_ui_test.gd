extends SceneTree

const State = preload("res://bars_state.gd")
const Authoring = preload("res://addons/mgs_editor/ui_authoring.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func packet(count: int = 3) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(32 + count * 72)
	for pair in [[0, 1], [4, 3], [8, count], [12, 72]]: data.encode_u32(pair[0], pair[1])
	for index in range(16, 32): data[index] = 7
	for index in count:
		var offset := 32 + index * 72
		var fields := [16, 16 + 12 * index, 896, 640, 1024, 5, 1, 0, 0x7f8f10, 0x3fdf1f]
		var title := "LIFE"
		if index == 1:
			fields = [16, 28, 768, 768, 1024, 4, 2, 0, 0xc03f1f, 0xff7f1f]
			title = "O2"
		elif index == 2:
			fields = [16, 40, 1400, 1200, 1500, 5, 0, 0, 0x9f6f10, 0x7fdf1f]
			title = "MG-REX"
		for word in fields.size(): data.encode_s32(offset + word * 4, fields[word])
		for character in title.length(): data[offset + 40 + character] = title.unicode_at(character)
	return data

func state_checks() -> State:
	var state := State.new()
	state.session_id.resize(16)
	state.session_id.fill(7)
	var bytes := packet()
	check(state.apply(bytes, {"epoch": 3}).is_empty(), "Valid bars rejected")
	check(state.current.is_empty(), "Bars displayed before frame presentation")
	check(state.present(3).bars.size() == 3, "Multi-bar state lost")
	for change in [[0, 2], [4, 4], [8, 17], [12, 71], [16, 0], [48, -1], [52, 6], [56, 3], [60, 2], [64, 0x1000000]]:
		var malformed := bytes.duplicate()
		malformed.encode_s32(change[0], change[1])
		check(not state.apply(malformed, {"epoch": 3}).is_empty(), "Invalid bar accepted: " + str(change))
	check(not state.apply(bytes.slice(0, bytes.size() - 1), {"epoch": 3}).is_empty(), "Truncated bars accepted")
	check(state.present(4).is_empty(), "Old epoch bars survived")
	state.present(3)
	return state

func run() -> void:
	var state := state_checks()
	var fixture := preload("res://tests/goggles_ui_test.gd").new()
	var originals: Dictionary = fixture.load_assets()
	var workspace := preload("res://addons/mgs_editor/mod_workspace.gd").new()
	workspace.root = "user://bars-ui-%d" % Time.get_ticks_usec()
	var authoring := Authoring.new()
	var path := authoring.open_ui(workspace, originals.root, originals.assets, originals.disc, "bars")
	check(not path.is_empty(), "Cannot create bars UI: " + authoring.error)
	if path.is_empty():
		fixture.free()
		quit(1)
		return
	var scene := load(path).instantiate() as Control
	root.add_child(scene)
	var session := authoring.attach(scene, originals.root, originals.assets, originals.disc)
	check(authoring.error.is_empty(), "Cannot preview bars: " + authoring.error)
	var life := scene.get_node("Life") as Control
	var label := life.get_node("Name") as Label
	check(life.get_node("Fill").size.x == 80, "Preview does not show actual health")
	check(life.get_node("Damage").position.x == 80 and life.get_node("Damage").size.x == 32, "Delayed health segment differs")
	check(label.get_theme_font("font").get_meta("mgs_retail_derived", false), "Original label font missing")
	life.position += Vector2(10, 2)
	label.add_theme_color_override("font_color", Color.BLUE)
	var gradient: GradientTexture2D = life.get_node("Fill/Gradient").texture
	gradient.gradient.set_color(0, Color.PURPLE)
	session.prepare_save()
	check(life.get_node("Fill").size.x == 128, "Preview fill value leaked into saved scene")
	check(not label.has_theme_font_override("font"), "Retail font would ship in ZIP")
	check(life.get_node("Fill/Gradient").texture.gradient.get_color(0) == Color.PURPLE, "User gradient edit lost on save")
	check(life.get_node("Fill/Gradient").texture.gradient.get_color(1).is_equal_approx(Color8(31, 223, 63)), "Preview gradient endpoint shipped as authored color")
	var packed := PackedScene.new()
	check(packed.pack(scene) == OK and ResourceSaver.save(packed, path) == OK, "Cannot save bars UI")
	session.finish_save()
	check(life.position == Vector2(26, 18), "Preview erased authored position")
	var exporter := preload("res://addons/mgs_editor/mod_export.gd").new()
	var archive: String = workspace.root.path_join("bars.zip")
	check(exporter.export_mod(workspace.root.path_join("mod.json"), archive).is_empty(), "Bars export failed: " + exporter.error)
	var zip := ZIPReader.new()
	check(zip.open(archive) == OK, "Cannot open bars ZIP")
	var files := Array(zip.get_files()).filter(func(file): return not file.ends_with("/"))
	check(files.size() == 4, "Bars ZIP shipped unexpected files: " + str(files))
	var installed: String = workspace.root.path_join("installed")
	for file in files:
		check(file.get_extension() in ["gd", "tscn", "json"], "Retail binary leaked into ZIP")
		var destination := installed.path_join(str(file))
		DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
		FileAccess.open(destination, FileAccess.WRITE).store_buffer(zip.read_file(file))
	zip.close()
	var registry := preload("res://mod_registry.gd").new()
	check(registry.configure({}, [installed.path_join("mod.json")]).is_empty(), "Relocated bars mod rejected")
	var presenter := preload("res://bars_presenter.gd").new()
	root.add_child(presenter)
	check(presenter.initialize(registry.ui, originals.root, originals.assets, originals.disc).is_empty(), "Cannot initialize exported bars")
	presenter.state.session_id = state.session_id
	check(presenter.state.apply(packet(), {"epoch": 3}).is_empty(), "Cannot apply native bars")
	presenter.present(3, true)
	var instances: Dictionary = presenter.ui.get("_instances")
	check(instances.size() == 3 and presenter.visible, "Native bars not instantiated")
	var player: Control = instances["1:LIFE:0"]
	check(player.position == Vector2(26, 18), "Native movement lost authored layout offset")
	check(player.get_node("Name").get_theme_color("font_color") == Color.BLUE, "ZIP lost custom text color")
	check(instances["0:MG-REX:0"].get_node("Background").size.x == 187, "Boss maximum ignored")
	check(instances["0:MG-REX:0"].get_node("Fill/Gradient").size.x == 150, "Boss fill stops at player maximum")
	var moved := packet()
	moved.encode_s32(36, -24)
	presenter.state.apply(moved, {"epoch": 3})
	presenter.present(3, true)
	check(player.position == Vector2(26, -22), "Native slide offset did not follow authored layout")
	var template := presenter.ui.get_node("Life") as Control
	presenter.ui.call("detach_originals")
	template.visible = false
	check(presenter.bind_originals().is_empty(), "Cannot bind hidden template")
	presenter.ui.call("apply_native_state", state.current)
	check(not instances.has("1:LIFE:0"), "Authored hidden bar became visible")
	presenter.present(3, false)
	check(not presenter.visible, "Disabled display left bars visible")
	presenter.state.apply(packet(0), {"epoch": 3})
	presenter.present(3, true)
	check(not presenter.visible and instances.is_empty(), "Frame reset left stale bars")
	scene.free()
	presenter.free()
	fixture.free()
	print("MGS_BARS_UI_TEST failures=%d" % failures)
	quit(1 if failures else 0)
