extends SceneTree

const Layout = preload("res://title_layout.gd")
var failures := 0
func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func packet() -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(72+55*52+132+80)
	for pair in [[0,1],[4,3],[8,1],[32,1],[36,21],[44,2],[48,1],[64,55],[68,1]]: data.encode_u32(pair[0],pair[1])
	for index in 16: data[16+index]=7
	for index in 55:
		var item: Array = Layout.ELEMENTS[index]
		var rect: Rect2 = item[2]
		var at := 72+index*52
		for pair in [[0,Layout.texture_id(item[1])],[4,rect.position.x],[8,rect.position.y],[12,rect.size.x],[16,rect.size.y],[28,64],[32,64],[36,0x808080],[40,0x404040],[44,1 if index==16 else 0],[48,0]]: data.encode_u32(at+pair[0],int(pair[1]))
	var at := 72+55*52+4
	for pair in [[0,1],[4,3],[8,1],[12,1],[32,1],[36,1],[48,12],[52,190],[56,128],[60,21],[76,128],[80,21],[84,1],[88,80],[128,4],[144,18],[148,1]]: data.encode_u32(at+pair[0],pair[1])
	for index in 16: data[at+16+index]=7
	data.encode_u16(at+102,32767)
	return data

func state_checks() -> void:
	var state := preload("res://title_state.gd").new()
	state.session_id.resize(16)
	state.session_id.fill(7)
	check(state.apply(packet(),{"epoch":3}).is_empty(),"Valid title rejected")
	check(state.current.is_empty(),"Title committed before FRAME")
	check(state.present(3).texts[0].layout.glyphs.size()==1,"Title text missing")
	for pair in [[0,2],[4,4],[8,0],[16,0],[32,2],[36,22],[40,6],[44,5],[48,2],[52,2],[64,56],[68,25],[72,65536],[84,4097],[100,0],[108,0x1000000],[116,8],[120,5]]:
		var invalid := packet()
		invalid.encode_u32(pair[0],pair[1])
		check(not state.apply(invalid,{"epoch":3}).is_empty(),"Invalid title accepted: "+str(pair))
	check(not state.apply(packet().slice(0,-1),{"epoch":3}).is_empty(),"Truncated title accepted")
	check(state.pending.texts[0].layout.glyphs.size()==1,"Rejected state changed retained text")
	check(state.present(4).is_empty(),"Title survived stage change")
	var hello := PackedByteArray()
	hello.resize(40)
	for pair in [[0,0x3152474d],[4,15],[8,23],[12,20],[16,33554431],[20,33554431]]: hello.encode_u32(pair[0],pair[1])
	var gate := preload("res://session_gate.gd").new()
	gate.capabilities=33554431
	gate.configure_token("00".repeat(16))
	check(gate.accept(1,hello).is_empty() and gate.accept(25,PackedByteArray()).is_empty(),"Title negotiation failed")
	gate=preload("res://session_gate.gd").new()
	gate.capabilities=33554431
	gate.configure_token("00".repeat(16))
	hello.encode_u32(8,22)
	check(not gate.accept(1,hello).is_empty(),"Old minor accepted required Title")

func relocate(workspace: RefCounted) -> Dictionary:
	var exporter := preload("res://addons/mgs_editor/mod_export.gd").new()
	var path: String = workspace.root.path_join("title.zip")
	check(exporter.export_mod(workspace.root.path_join("mod.json"),path).is_empty(),"Title export failed: "+exporter.error)
	var zip := ZIPReader.new()
	check(zip.open(path)==OK,"Cannot open Title ZIP")
	var installed: String = workspace.root.path_join("relocated")
	var files := Array(zip.get_files()).filter(func(file):return not file.ends_with("/"))
	check(files.size()==9,"Unexpected Title dependencies: "+str(files))
	for file in files:
		check(file.get_extension() in ["gd","tscn","json"],"Original artwork in Title ZIP")
		var target := installed.path_join(str(file))
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		FileAccess.open(target,FileAccess.WRITE).store_buffer(zip.read_file(file))
	zip.close()
	var registry := preload("res://mod_registry.gd").new()
	check(registry.configure({},[installed.path_join("mod.json")]).is_empty(),"Relocated Title rejected")
	return registry.ui

func run() -> void:
	state_checks()
	var args := Array(OS.get_cmdline_user_args())
	var directory: String = args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://../../../.local/godot-content")
	var catalog = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("catalog.json")))
	var workspace := preload("res://addons/mgs_editor/mod_workspace.gd").new()
	workspace.root="user://title-test-%d"%Time.get_ticks_usec()
	var authoring := preload("res://addons/mgs_editor/ui_authoring.gd").new()
	var path := authoring.open_ui(workspace,directory,catalog.assets,int(catalog.disc),"title")
	check(not path.is_empty(),"Cannot author title: "+authoring.error)
	if path.is_empty():
		quit(1)
		return
	var scene := load(path).instantiate() as Control
	root.add_child(scene)
	check(scene.get_node_or_null("Back")==null and scene.get_node_or_null("ActionError")==null,"Default title contains added UI")
	for button_path in ["Title/SkipIntro/Interact","Title/PressStart/Interact","Menu/NewGame/Interact","Difficulty/Level2/Interact"]:
		check(scene.get_node(button_path).mouse_filter==Control.MOUSE_FILTER_STOP,"Title button ignores mouse: "+button_path)
	var session := authoring.attach(scene,directory,catalog.assets,int(catalog.disc))
	check(authoring.error.is_empty(),"Title preview failed: "+authoring.error)
	check(scene.get_node("Title/Logo").texture!=null,"Local title artwork absent")
	scene.preview_page=2
	scene.update_preview()
	check(scene.get_node("Difficulty").visible,"Difficulty preview absent")
	scene.get_node("Title/SelectDifficulty").position+=Vector2(8,3)
	scene.get_node("Title/Copyright").hide()
	scene.get_node("Title/BackgroundLeft").texture=GradientTexture2D.new()
	session.prepare_save()
	var packed := PackedScene.new()
	check(packed.pack(scene)==OK and ResourceSaver.save(packed,path)==OK,"Cannot save title")
	session.finish_save()
	var presenter := preload("res://title_presenter.gd").new()
	root.add_child(presenter)
	check(presenter.initialize(relocate(workspace),directory,catalog.assets,int(catalog.disc)).is_empty(),"Cannot initialize relocated title")
	presenter.state.session_id.resize(16)
	presenter.state.session_id.fill(7)
	check(presenter.state.apply(packet(),{"epoch":3}).is_empty(),"Cannot apply title packet")
	for tick in 3:
		presenter.ui.apply_native_state(presenter.state.pending)
		presenter.present(3,true)
		check(presenter.ui.get_node("Title/SelectDifficulty").position==Vector2(82,30),"Title placement drift")
	check(not presenter.ui.get_node("Title/Copyright").visible,"Hidden title element restored")
	check(presenter.ui.get_node("Title/BackgroundLeft").texture is GradientTexture2D,"Custom title artwork lost")
	check(presenter.ui.get_node("Help/Text00")._layout.glyphs.size()==1,"Title help text missing")
	check(presenter.ui.get_node("Difficulty/Level2").self_modulate.is_equal_approx(Color(1.5,1.5,1.5)),"Native selected difficulty absent")
	var warning: Dictionary = presenter.state.pending.duplicate(true)
	warning.merge({"mode":18,"storage_a":3,"storage_b":0},true)
	presenter.ui.apply_native_state(warning)
	check(presenter.ui.get_node("StorageWarning/Status0").text=="   FULL" and presenter.ui.get_node("StorageWarning/Status1").text=="NO CARD","Original storage status missing")
	check(presenter.ui.get_node("Help/Text00")._layout.glyphs.size()==1,"Storage warning hid native help text")
	presenter.present(4,true)
	check(not presenter.visible,"Stale title visible")
	scene.free()
	presenter.free()
	print("MGS_TITLE_UI_TEST failures=%d"%failures)
	quit(1 if failures else 0)
