extends SceneTree

var failures := 0
func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func packet(images: bool = true) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(400 + (4*6656 if images else 0))
	for field in [[0,1],[4,3],[8,15 if images else 0],[32,1],[40,5],[44,14085],[52,8],[96,31],[100,30],[104,52],[108,89],[116,54],[120,40],[124,1],
		[128,237],[132,30],[136,52],[140,89],[148,54],[152,30],[156,1],[192,1],[196,3],[200,1],[204,1],[224,1],[228,1],[240,34],[244,132],[248,252],[252,76],[268,252],[272,76],[276,1],[280,80],[320,4],[336,18],[340,1]]:
		data.encode_u32(field[0],field[1])
	for offset in [16,208]:
		for index in 16: data[offset+index]=7
	data.encode_u16(290,32767)
	if images:
		for index in 4:
			var at := 400 + index*6656
			for pixel in 6144: data[at+pixel] = 1 if pixel%64<26 else 2
			data.encode_u16(at+6146,31 if index<2 else 992)
			data.encode_u16(at+6148,31744)
	return data

func state_checks() -> void:
	var state := preload("res://codec_state.gd").new()
	state.session_id.resize(16)
	state.session_id.fill(7)
	check(not state.apply(packet(false),{"epoch":3}).is_empty(),"Missing epoch portraits accepted")
	check(state.apply(packet(),{"epoch":3}).is_empty(),"Valid Codec rejected")
	check(state.current.is_empty(),"Codec committed before FRAME")
	check(state.present(3).message.layout.glyphs.size()==1,"Codec text lost")
	for change in [[0,2],[4,4],[8,16],[12,1],[16,0],[32,2],[40,21],[44,15000],[48,16],[52,10],[56,256],[84,33],[88,6],[104,53],[112,129],[116,57],[124,2],[160,100],[196,4],[208,0],[276,4097]]:
		var invalid := packet()
		invalid.encode_u32(change[0],change[1])
		check(not state.apply(invalid,{"epoch":3}).is_empty(),"Invalid Codec accepted: "+str(change))
	check(not state.apply(packet().slice(0,-1),{"epoch":3}).is_empty(),"Truncated portraits accepted")
	check(state.apply(packet(false),{"epoch":3}).is_empty(),"Retained portraits lost")
	check(state.pending.images[2].decode_u16(6146)==992,"Portrait palette changed")
	check(state.present(4).is_empty(),"Codec survived epoch change")
	var hello := PackedByteArray()
	hello.resize(40)
	for pair in [[0,0x3152474d],[4,15],[8,20],[12,20],[16,4194303],[20,4194303]]: hello.encode_u32(pair[0],pair[1])
	var gate := preload("res://session_gate.gd").new()
	gate.capabilities=4194303
	gate.configure_token("00000000000000000000000000000000")
	check(gate.accept(1,hello).is_empty() and gate.accept(22,PackedByteArray()).is_empty(),"Codec negotiation failed")

func relocate(workspace: RefCounted) -> Dictionary:
	var exporter := preload("res://addons/mgs_editor/mod_export.gd").new()
	var path: String = workspace.root.path_join("codec.zip")
	check(exporter.export_mod(workspace.root.path_join("mod.json"),path).is_empty(),"Codec export failed: "+exporter.error)
	var zip := ZIPReader.new()
	check(zip.open(path)==OK,"Cannot open Codec ZIP")
	var installed: String = workspace.root.path_join("relocated")
	var files := Array(zip.get_files()).filter(func(file):return not file.ends_with("/"))
	check(files.size()==8,"Unexpected Codec dependencies: "+str(files))
	for file in files:
		check(file.get_extension() in ["gd","tscn","json"],"Original artwork in Codec ZIP")
		var target := installed.path_join(str(file))
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		FileAccess.open(target,FileAccess.WRITE).store_buffer(zip.read_file(file))
	zip.close()
	var registry := preload("res://mod_registry.gd").new()
	check(registry.configure({},[installed.path_join("mod.json")]).is_empty(),"Relocated Codec rejected")
	return registry.ui

func run() -> void:
	state_checks()
	var args := Array(OS.get_cmdline_user_args())
	var directory: String = args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://../../../.local/godot-content")
	var catalog = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("catalog.json")))
	var workspace := preload("res://addons/mgs_editor/mod_workspace.gd").new()
	workspace.root = "user://codec-test-%d"%Time.get_ticks_usec()
	var authoring := preload("res://addons/mgs_editor/ui_authoring.gd").new()
	var path := authoring.open_ui(workspace,directory,catalog.assets,int(catalog.disc),"codec")
	check(not path.is_empty(),"Cannot author Codec: "+authoring.error)
	if path.is_empty():
		quit(1)
		return
	var scene := load(path).instantiate() as Control
	root.add_child(scene)
	check(scene.get_node_or_null("ActionError")==null,"Default Codec contains diagnostic text")
	for button in scene.find_children("*","Button",true,false):
		check(button.text.is_empty() and button.tooltip_text.is_empty(),"Codec interaction adds visible text")
	var session := authoring.attach(scene,directory,catalog.assets,int(catalog.disc))
	check(authoring.error.is_empty(),"Cannot preview Codec: "+authoring.error)
	scene.preview_mode=3
	scene.update_preview()
	check(scene.get_node("Incoming").visible and scene.get_node("Incoming/Call").texture!=null,"Incoming preview missing")
	scene.get_node("Panel/LeftPortrait").position+=Vector2(5,2)
	var custom := GradientTexture2D.new()
	scene.get_node("Panel/RightPortrait/Current").texture=custom
	scene.get_node("Panel/Console/Memory").hide()
	session.prepare_save()
	var packed := PackedScene.new()
	check(packed.pack(scene)==OK and ResourceSaver.save(packed,path)==OK,"Codec save failed")
	session.finish_save()
	var presenter := preload("res://codec_presenter.gd").new()
	root.add_child(presenter)
	check(presenter.initialize(relocate(workspace),directory,catalog.assets,int(catalog.disc)).is_empty(),"Cannot initialize relocated Codec")
	presenter.state.session_id.resize(16)
	presenter.state.session_id.fill(7)
	check(presenter.state.apply(packet(),{"epoch":3}).is_empty(),"Cannot apply Codec")
	for tick in 3:
		presenter.ui.apply_native_state(presenter.state.pending)
		presenter.present(3,true)
		check(presenter.ui.get_node("Panel/LeftPortrait").position==Vector2(36,32),"Authored portrait position drift")
	check(presenter.ui.get_node("Panel/LeftPortrait/Current").texture!=null,"Native portrait absent")
	check(presenter.ui.get_node("Panel/RightPortrait/Current").texture is GradientTexture2D,"Custom portrait lost")
	check(not presenter.ui.get_node("Panel/Console/Memory").visible,"Authored hidden element restored")
	check(presenter.ui.get_node("Panel/Console/Frequency/Digit0/Segment0").visible,"Inactive digit background removed")
	check(not presenter.ui.get_node("Panel/Console/Foreground/Frequency/Digit0/Segment0").visible,"Incorrect active frequency segment")
	check(presenter.ui.get_node("Panel/Console/Foreground/Frequency/Digit0/Segment2").visible,"Active frequency segment absent")
	check(presenter.ui.get_node("Panel/Console/Signal/Row1").visible and not presenter.ui.get_node("Panel/Console/Foreground/Signal/Row1").visible,"Signal background lost")
	check(presenter.ui.get_node("Panel/Message")._layout.glyphs.size()==1,"Native dialogue missing")
	presenter.present(4,true)
	check(not presenter.visible,"Old Codec still visible")
	scene.free()
	presenter.free()
	print("MGS_CODEC_UI_TEST failures=%d"%failures)
	quit(1 if failures else 0)
