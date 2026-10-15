extends SceneTree

const Layout = preload("res://options_layout.gd")
var failures := 0
func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func packet() -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(104+57*32+132+80)
	for pair in [[0,1],[4,3],[8,1],[32,1],[36,1],[40,53],[44,1],[96,57],[100,1]]: data.encode_u32(pair[0],pair[1])
	for index in 16: data[16+index]=7
	for index in 57:
		var item: Array = Layout.ELEMENTS[index]
		var rect: Rect2 = item[2]
		var at := 104+index*32
		for pair in [[0,Layout.texture_id(item[1])],[4,rect.position.x],[8,rect.position.y],[12,rect.size.x],[16,rect.size.y],[20,0x808080],[24,3 if index in [21,22] else 1 if index<27 else 0],[28,0]]: data.encode_u32(at+pair[0],int(pair[1]))
		if index >= 48:
			data.encode_u32(at+24,2)
			data.encode_u32(at+28,2)
		if index == 10: data.encode_u32(at+28,1)
	var at := 104+57*32+4
	for pair in [[0,1],[4,3],[8,1],[12,1],[32,1],[36,1],[48,12],[52,190],[56,128],[60,21],[76,128],[80,21],[84,1],[88,80],[128,4],[144,18],[148,1]]: data.encode_u32(at+pair[0],pair[1])
	for index in 16: data[at+16+index]=7
	data.encode_u16(at+102,32767)
	return data

func state_checks() -> void:
	var state := preload("res://options_state.gd").new()
	state.session_id.resize(16)
	state.session_id.fill(7)
	check(state.apply(packet(),{"epoch":3}).is_empty(),"Valid Options rejected")
	check(state.current.is_empty(),"Options committed before FRAME")
	check(state.present(3).texts[0].layout.glyphs.size()==1,"Options text missing")
	for pair in [[0,2],[4,4],[8,0],[16,0],[32,2],[36,12],[40,54],[44,3],[48,10],[52,3],[56,3],[60,2],[64,2],[96,58],[100,32],[104,65536],[116,1025],[124,0x1000000],[128,4],[132,5]]:
		var invalid := packet()
		invalid.encode_u32(pair[0],pair[1])
		check(not state.apply(invalid,{"epoch":3}).is_empty(),"Invalid Options accepted: "+str(pair))
	check(not state.apply(packet().slice(0,-1),{"epoch":3}).is_empty(),"Truncated text accepted")
	check(state.pending.texts[0].layout.glyphs.size()==1,"Rejected state mutated text")
	check(state.present(4).is_empty(),"Options survived stage change")
	var hello := PackedByteArray()
	hello.resize(40)
	for pair in [[0,0x3152474d],[4,15],[8,21],[12,20],[16,8388607],[20,8388607]]: hello.encode_u32(pair[0],pair[1])
	var gate := preload("res://session_gate.gd").new()
	gate.capabilities=8388607
	gate.configure_token("00".repeat(16))
	check(gate.accept(1,hello).is_empty() and gate.accept(23,PackedByteArray()).is_empty(),"Options negotiation failed")
	gate=preload("res://session_gate.gd").new()
	gate.capabilities=8388607
	gate.configure_token("00".repeat(16))
	hello.encode_u32(8,20)
	check(not gate.accept(1,hello).is_empty(),"Old minor accepted required Options")

func relocate(workspace: RefCounted) -> Dictionary:
	var exporter := preload("res://addons/mgs_editor/mod_export.gd").new()
	var path: String = workspace.root.path_join("options.zip")
	check(exporter.export_mod(workspace.root.path_join("mod.json"),path).is_empty(),"Options export failed: "+exporter.error)
	var zip := ZIPReader.new()
	check(zip.open(path)==OK,"Cannot open Options ZIP")
	var installed: String = workspace.root.path_join("relocated")
	var files := Array(zip.get_files()).filter(func(file):return not file.ends_with("/"))
	check(files.size()==8,"Unexpected Options dependencies: "+str(files))
	for file in files:
		check(file.get_extension() in ["gd","tscn","json"],"Original artwork in Options ZIP")
		var target := installed.path_join(str(file))
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		FileAccess.open(target,FileAccess.WRITE).store_buffer(zip.read_file(file))
	zip.close()
	var registry := preload("res://mod_registry.gd").new()
	check(registry.configure({},[installed.path_join("mod.json")]).is_empty(),"Relocated Options rejected")
	return registry.ui

func run() -> void:
	state_checks()
	var args := Array(OS.get_cmdline_user_args())
	var directory: String = args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://../../../.local/godot-content")
	var catalog = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("catalog.json")))
	var workspace := preload("res://addons/mgs_editor/mod_workspace.gd").new()
	workspace.root="user://options-test-%d"%Time.get_ticks_usec()
	var authoring := preload("res://addons/mgs_editor/ui_authoring.gd").new()
	var path := authoring.open_ui(workspace,directory,catalog.assets,int(catalog.disc),"options")
	check(not path.is_empty(),"Cannot author Options: "+authoring.error)
	if path.is_empty():
		quit(1)
		return
	var scene := load(path).instantiate() as Control
	root.add_child(scene)
	var session := authoring.attach(scene,directory,catalog.assets,int(catalog.disc))
	check(authoring.error.is_empty(),"Options preview failed: "+authoring.error)
	check(scene.get_node("Options/Captions").texture!=null,"Local Options artwork absent")
	scene.preview_page=2
	scene.update_preview()
	check(scene.get_node("Controller/ControllerDiagram").visible and not scene.get_node("Options/Captions").visible,"Controller preview incorrect")
	scene.preview_page=0
	scene.update_preview()
	check(scene.get_node("Selection/FocusCenter").size==Vector2(96,8),"Selection highlight collapsed")
	scene.preview_selection=3
	scene.update_preview()
	check(scene.get_node("Selection/FocusCenter").position==Vector2(120,86),"Selection highlight did not follow preview")
	scene.preview_selection=1
	scene.update_preview()
	scene.get_node("Options/Captions").position+=Vector2(8,3)
	scene.get_node("Options/Sound").hide()
	scene.get_node("Options/BackgroundLeft").texture=GradientTexture2D.new()
	scene.get_node("Options/CaptionOff").use_native_color=false
	scene.get_node("Options/CaptionOff").self_modulate=Color(0.7,0.8,0.9,0.8)
	session.prepare_save()
	var packed := PackedScene.new()
	check(packed.pack(scene)==OK and ResourceSaver.save(packed,path)==OK,"Cannot save Options")
	session.finish_save()
	var presenter := preload("res://options_presenter.gd").new()
	root.add_child(presenter)
	check(presenter.initialize(relocate(workspace),directory,catalog.assets,int(catalog.disc)).is_empty(),"Cannot initialize relocated Options")
	presenter.state.session_id.resize(16)
	presenter.state.session_id.fill(7)
	check(presenter.state.apply(packet(),{"epoch":3}).is_empty(),"Cannot apply Options packet")
	for tick in 3:
		presenter.ui.apply_native_state(presenter.state.pending)
		presenter.present(3,true)
		check(presenter.ui.get_node("Options/Captions").position==Vector2(118,55),"Options placement drift")
		check(presenter.ui.get_node("Options/CaptionOff").self_modulate.is_equal_approx(Color(0.7,0.8,0.9,0.4)),"Authored color fades across native updates")
	check(not presenter.ui.get_node("Options/Sound").visible,"Hidden setting restored")
	check(presenter.ui.get_node("Options/BackgroundLeft").texture is GradientTexture2D,"Custom Options texture lost")
	check(presenter.ui.get_node("Help/Text00")._layout.glyphs.size()==1,"Options help text missing")
	presenter.present(4,true)
	check(not presenter.visible,"Stale Options visible")
	scene.free()
	presenter.free()
	print("MGS_OPTIONS_UI_TEST failures=%d"%failures)
	quit(1 if failures else 0)
