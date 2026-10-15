extends SceneTree

const State = preload("res://radar_state.gd")
const Authoring = preload("res://addons/mgs_editor/ui_authoring.gd")
const FOREGROUND = "Radar/Interior/AlertClip/Panel/Foreground"
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func packet(mode: int = 0, active: int = 1) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(104 + active * 216)
	for entry in [[0,1], [4,3], [8,active], [12,active], [16,active], [20,152], [24,40], [28,24]]:
		data.encode_u32(entry[0], entry[1])
	for index in range(32,48): data[index] = 7
	var fields := [active, mode, 12, 0, 0, 13, 190, 0, 16, 5, 5400, active, 0, 123456]
	for index in fields.size(): data.encode_s32(48 + index * 4, fields[index])
	if active:
		data.encode_s32(104, 12)
		data.encode_u32(112, 1)
		data.encode_u32(124, 0x0080ff)
		for pair in [[256,4], [260,-16], [264,12], [272,12], [276,-23], [280,20], [284,-16], [288,0x808000], [292,0x100000], [296,-25], [300,-20], [304,25], [308,-20]]:
			data.encode_s32(pair[0], pair[1])
	return data

func state_checks() -> State:
	var state := State.new()
	state.session_id.resize(16)
	state.session_id.fill(7)
	var bytes := packet()
	check(state.apply(bytes, {"epoch":3}).is_empty(), "Valid radar rejected")
	check(state.current.is_empty(), "Radar shown before FRAME")
	check(state.present(3).contacts[0].position == Vector2(12,0), "Radar contact changed")
	check(state.current.walls[0].from == Vector2(-25,-20), "Radar wall changed")
	for change in [[0,2], [4,4], [8,97], [12,97], [16,4097], [20,151], [24,39], [28,23], [32,0], [48,2], [52,4], [60,32769], [68,-1], [72,257], [76,94], [80,57], [92,2], [96,2], [112,4], [116,96], [120,65536], [124,0x1000000], [288,0x1000000], [312,3], [316,2]]:
		var malformed := bytes.duplicate()
		malformed.encode_s32(change[0], change[1])
		check(not state.apply(malformed, {"epoch":3}).is_empty(), "Invalid radar accepted: " + str(change))
	check(not state.apply(bytes.slice(0,319), {"epoch":3}).is_empty(), "Truncated radar accepted")
	check(state.present(4).is_empty(), "Old radar survived epoch")
	state.present(3)
	return state

func export_relocated(workspace: RefCounted) -> Dictionary:
	var exporter := preload("res://addons/mgs_editor/mod_export.gd").new()
	var archive: String = workspace.root.path_join("radar.zip")
	check(exporter.export_mod(workspace.root.path_join("mod.json"), archive).is_empty(), "Radar export failed: " + exporter.error)
	var zip := ZIPReader.new()
	check(zip.open(archive) == OK, "Cannot open radar ZIP")
	var files := Array(zip.get_files()).filter(func(file): return not file.ends_with("/"))
	check(files.size() == 7, "Unexpected ZIP dependencies: " + str(files))
	var installed: String = workspace.root.path_join("installed")
	for file in files:
		check(file.get_extension() in ["gd", "tscn", "json"], "Retail binary in radar ZIP")
		var destination := installed.path_join(str(file))
		DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
		FileAccess.open(destination, FileAccess.WRITE).store_buffer(zip.read_file(file))
	zip.close()
	var registry := preload("res://mod_registry.gd").new()
	check(registry.configure({}, [installed.path_join("mod.json")]).is_empty(), "Relocated radar rejected")
	return registry.ui

func run() -> void:
	var state := state_checks()
	var arguments := Array(OS.get_cmdline_user_args()).filter(func(value): return not value.begins_with("--"))
	var directory: String = arguments[0] if not arguments.is_empty() else ProjectSettings.globalize_path("res://../../../.local/godot-content")
	var catalog = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("catalog.json")))
	if not catalog is Dictionary:
		push_error("Prepare local disc UI assets before radar UI tests")
		quit(1)
		return
	var workspace := preload("res://addons/mgs_editor/mod_workspace.gd").new()
	workspace.root = "user://radar-ui-%d" % Time.get_ticks_usec()
	var authoring := Authoring.new()
	var path := authoring.open_ui(workspace, directory, catalog.assets, int(catalog.disc), "radar")
	check(not path.is_empty(), "Cannot author radar: " + authoring.error)
	if path.is_empty():
		quit(1)
		return
	var scene := load(path).instantiate() as Control
	root.add_child(scene)
	var session := authoring.attach(scene, directory, catalog.assets, int(catalog.disc))
	check(authoring.error.is_empty(), "Cannot preview radar: " + authoring.error)
	var panel: Control = scene.get_node("Radar")
	var header: TextureRect = scene.get_node(FOREGROUND + "/Header")
	var background: ColorRect = scene.get_node("Radar/Interior/MapClip/Background")
	for mode in 5:
		scene.preview_mode = mode
		scene.update_preview()
		check(scene.get_node("Radar/Interior/MapClip").visible == (mode == 0), "Wrong map visibility")
		check(scene.get_node("Radar/Interior/AlertClip").visible == (mode in [1,2,3]), "Wrong alert visibility")
		check(scene.get_node("Radar/Interior/Countdown").visible == (mode == 4), "Wrong countdown visibility")
	check(header.texture != null and header.texture.has_meta("mgs_retail_derived"), "Original header missing")
	scene.preview_mode = 3
	scene.update_preview()
	panel.position += Vector2(-80, 8)
	header.position += Vector2(2, 3)
	scene.map_background = Color(0.1, 0.2, 0.3, 0.7)
	var custom := GradientTexture2D.new()
	header.texture = custom
	scene.update_preview()
	check(header.texture == custom, "Custom header texture replaced by original")
	session.prepare_save()
	check(panel.position == Vector2(154,23), "Authored radar move lost on save")
	check(header.position == Vector2(14,4), "Authored header move lost on save")
	check(background.color.is_equal_approx(Color8(0,24,24,128)), "Preview background saved as authored color")
	for node in scene.find_children("*", "TextureRect", true, false):
		check(node.texture == null or not node.texture.has_meta("mgs_retail_derived"), "Original artwork would ship")
	var packed := PackedScene.new()
	check(packed.pack(scene) == OK and ResourceSaver.save(packed, path) == OK, "Cannot save radar")
	session.finish_save()
	var presenter := preload("res://radar_presenter.gd").new()
	root.add_child(presenter)
	check(presenter.initialize(export_relocated(workspace), directory, catalog.assets, int(catalog.disc)).is_empty(), "Cannot initialize relocated radar")
	presenter.state.session_id = state.session_id
	presenter.state.apply(packet(), {"epoch":3})
	presenter.present(3, true)
	check(presenter.visible and presenter.ui.get_node("Radar").position == Vector2(154,23), "Runtime lost authored offset")
	check(presenter.ui.map_background == scene.map_background, "ZIP lost palette override")
	var moved := packet(3)
	moved.encode_s32(64, -16)
	presenter.state.apply(moved, {"epoch":3})
	presenter.present(3, true)
	check(presenter.ui.get_node("Radar").position == Vector2(154,7), "Native slide lost authored offset")
	check(presenter.ui.get_node(FOREGROUND + "/Header").texture is GradientTexture2D, "ZIP lost custom header")
	presenter.present(3, false)
	check(not presenter.visible, "Display suppression failed")
	presenter.state.apply(packet(0,0), {"epoch":3})
	presenter.present(3, true)
	check(not presenter.visible, "Inactive radar still visible")
	var recovering := packet()
	recovering.encode_s32(76, 69)
	presenter.state.apply(recovering, {"epoch":3})
	presenter.present(3, true)
	check(presenter.ui.get_node("Radar/Interior/MapClip").size.x == 24, "Recovery reveal width differs")
	presenter.present(4, true)
	check(not presenter.visible, "Old epoch radar visible")
	scene.free()
	presenter.free()
	print("MGS_RADAR_UI_TEST failures=%d" % failures)
	quit(1 if failures else 0)
