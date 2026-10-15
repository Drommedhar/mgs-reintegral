extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func packet(active: bool = true, text: bool = false) -> PackedByteArray:
	var data := PackedByteArray()
	var count := 3 if active else 0
	data.resize(176 + count * 80 + (80 if text else 0))
	for field in [[0,1],[4,3],[8,count],[12,80],[16,0xffffffff],[48,1],[52,3],[136,80]]:
		data.encode_u32(field[0], field[1])
	for offset in [32,64]:
		for index in 16: data[offset + index] = 7
	if active:
		var panels := [[0,13,16,184,22,4,3,5,0,0,0,0], [1,0,260,184,1,132,12,46,0,8,12,0], [0,17,16,150,27,40,1,1,3,0,0,0]]
		for index in 3:
			for word in 12: data.encode_s32(176 + index * 80 + word * 4, panels[index][word])
			var name: PackedByteArray = ["RATION","SOCOM","CARD"][index].to_ascii_buffer()
			for letter in name.size(): data[224 + index * 80 + letter] = name[letter]
	if text:
		for field in [[56,1],[60,1],[80,1],[84,1],[96,86],[100,72],[104,200],[108,80],[124,200],[128,80],[132,1]]:
			data.encode_u32(field[0], field[1])
		data.encode_u16(146,32767)
		var glyph := 176 + count * 80
		for field in [[0,4],[16,18],[20,1]]: data.encode_u32(glyph + field[0],field[1])
	return data

func state_checks() -> RefCounted:
	var state := preload("res://inventory_state.gd").new()
	state.session_id.resize(16)
	state.session_id.fill(7)
	check(state.apply(packet(), {"epoch":3}).is_empty(), "Valid inventory rejected")
	check(state.current.is_empty(), "Inventory shown before FRAME")
	check(state.present(3).panels[2].level == 3, "Card level lost")
	for change in [[0,2],[4,4],[8,33],[12,79],[16,3],[20,1],[32,0],[52,4],[64,0],[176,2],[180,24],[192,33],[196,256],[216,101]]:
		var data := packet()
		data.encode_s32(change[0],change[1])
		check(not state.apply(data, {"epoch":3}).is_empty(), "Malformed inventory accepted: " + str(change))
	check(not state.apply(packet().slice(0,415), {"epoch":3}).is_empty(), "Truncated inventory accepted")
	check(state.apply(packet(true,true), {"epoch":3}).is_empty(), "Formatted description rejected")
	check(state.present(3).description.layout.glyphs.size() == 1, "Description glyph lost")
	var retained := packet(true,true).slice(0,416)
	for offset in [60,124,128,132]: retained.encode_u32(offset,0)
	check(state.apply(retained, {"epoch":3}).is_empty(), "Retained description rejected")
	check(state.present(4).is_empty(), "Inventory survived epoch change")
	return state

func export_relocated(workspace: RefCounted) -> Dictionary:
	var exporter := preload("res://addons/mgs_editor/mod_export.gd").new()
	var path: String = workspace.root.path_join("inventory.zip")
	check(exporter.export_mod(workspace.root.path_join("mod.json"),path).is_empty(), "Inventory export failed: " + exporter.error)
	var zip := ZIPReader.new()
	check(zip.open(path) == OK, "Cannot read inventory ZIP")
	var files := Array(zip.get_files()).filter(func(file): return not file.ends_with("/"))
	check(files.size() == 9, "Unexpected inventory ZIP dependencies: " + str(files))
	var installed: String = workspace.root.path_join("installed")
	for file in files:
		check(file.get_extension() in ["gd","tscn","json"], "Retail binary shipped in inventory ZIP")
		var target := installed.path_join(str(file))
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		FileAccess.open(target,FileAccess.WRITE).store_buffer(zip.read_file(file))
	zip.close()
	var registry := preload("res://mod_registry.gd").new()
	check(registry.configure({},[installed.path_join("mod.json")]).is_empty(), "Relocated inventory rejected")
	return registry.ui

func run() -> void:
	state_checks()
	var args := Array(OS.get_cmdline_user_args())
	var directory: String = args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://../../../.local/godot-content")
	var catalog = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("catalog.json")))
	var workspace := preload("res://addons/mgs_editor/mod_workspace.gd").new()
	workspace.root = "user://inventory-test-%d" % Time.get_ticks_usec()
	var authoring := preload("res://addons/mgs_editor/ui_authoring.gd").new()
	var path := authoring.open_ui(workspace,directory,catalog.assets,int(catalog.disc),"inventory")
	check(not path.is_empty(), "Cannot author inventory: " + authoring.error)
	if path.is_empty():
		quit(1)
		return
	var scene := load(path).instantiate() as Control
	root.add_child(scene)
	check(scene.find_children("*","Button",true,false).is_empty(),"Default inventory contains added buttons or click areas")
	check(scene.get_node_or_null("Actions")==null and scene.get_node_or_null("ActionError")==null,"Default inventory contains an added footer")
	var session := authoring.attach(scene,directory,catalog.assets,int(catalog.disc))
	check(authoring.error.is_empty(), "Cannot preview inventory: " + authoring.error)
	scene.preview_mode = 1
	scene.update_preview()
	var icon: TextureRect = scene.get_node("Item/Icon")
	check(icon.texture != null and icon.texture.has_meta("mgs_retail_derived"), "Original item icon missing")
	check(scene.get_node("Item/Count").text == "3/5", "Item counter missing")
	check(scene.get_node("Description").visible, "Description preview missing")
	scene.get_node("Item").position += Vector2(12,-5)
	icon.position += Vector2(2,3)
	var icon_point := icon.position
	var custom := GradientTexture2D.new()
	scene.get_node("Weapon/Icon").texture = custom
	scene.get_node("Item").highlight_color = Color.RED
	scene.get_node("Weapon/Name").position.x -= 7
	scene.update_preview()
	check(icon.position == icon_point, "Native icon offset accumulated")
	session.prepare_save()
	check(scene.get_node("Item").position == Vector2(28,179), "Authored item position lost")
	check(icon.position == Vector2(2,3), "Authored icon offset lost")
	for node in scene.find_children("*","TextureRect",true,false):
		check(node.texture == null or not node.texture.has_meta("mgs_retail_derived"), "Original texture survived detach")
	var packed := PackedScene.new()
	check(packed.pack(scene) == OK and ResourceSaver.save(packed,path) == OK, "Cannot save inventory scene")
	session.finish_save()
	var presenter := preload("res://inventory_presenter.gd").new()
	root.add_child(presenter)
	check(presenter.initialize(export_relocated(workspace),directory,catalog.assets,int(catalog.disc)).is_empty(), "Cannot initialize exported inventory")
	presenter.state.session_id.resize(16)
	presenter.state.session_id.fill(7)
	for tick in 3:
		check(presenter.state.apply(packet(), {"epoch":3}).is_empty(), "Cannot apply inventory")
		presenter.ui.apply_native_state(presenter.state.pending)
		presenter.present(3,true)
		check(presenter.ui.get_node("Item").position == Vector2(28,179), "Runtime lost authored panel position")
		check(presenter.ui.get_node("NativePanel2/Count").text == "3", "Carousel card level missing")
		check(presenter.ui.get_node("NativePanel2/Count").position == Vector2(18,12), "Carousel offset accumulated")
		var title: Label = presenter.ui.get_node("Weapon/Name")
		check(is_equal_approx(title.position.x + title.size.x, 39), "Authored inventory name alignment lost in ZIP")
	check(presenter.ui.get_node("Weapon/Icon").texture is GradientTexture2D, "Custom icon lost in ZIP")
	check(presenter.ui.get_node("Item").highlight_color == Color.RED, "Custom panel palette lost")
	presenter.ui.get_node("Item/Icon").hide()
	presenter.ui.apply_native_state(presenter.state.pending)
	check(not presenter.ui.get_node("Item/Icon").visible, "Authored icon visibility ignored")
	presenter.state.apply(packet(true,true), {"epoch":3})
	presenter.present(3,true)
	check(presenter.ui.get_node("Description/Text")._layout.glyphs.size() == 1, "Native description not displayed")
	check(not presenter.ui.get_node("Description/Preview").visible, "Preview text leaked into native description")
	presenter.present(3,false)
	check(not presenter.visible, "Display suppression failed")
	presenter.state.apply(packet(false), {"epoch":3})
	presenter.present(3,true)
	check(not presenter.visible, "Inactive inventory visible")
	presenter.present(4,true)
	check(not presenter.visible, "Old epoch inventory visible")
	scene.free()
	presenter.free()
	print("MGS_INVENTORY_UI_TEST failures=%d" % failures)
	quit(1 if failures else 0)
