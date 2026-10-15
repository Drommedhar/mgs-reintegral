extends SceneTree

var failures := 0
func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func packet() -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(164)
	for pair in [[0,1],[4,3],[24,1],[28,1],[32,1],[36,0],[40,0],[48,1],[52,7],[56,1],[60,0],[64,1],
		[68,7],[72,1],[76,24],[80,2],[84,2],[88,0],[92,1],[96,1]]: data.encode_u32(pair[0],pair[1])
	for index in 16: data[8+index]=7
	for index in 4: data[100+index]="Dock".to_ascii_buffer()[index]
	return data

func state_checks() -> void:
	var state := preload("res://save_state.gd").new()
	state.session_id.resize(16)
	state.session_id.fill(7)
	check(state.apply(packet(),{"epoch":3}).is_empty(),"Valid save rejected")
	check(state.current.is_empty(),"Save committed before FRAME")
	check(state.present(3).entries[0].location=="Dock","Location absent")
	for pair in [[0,2],[4,4],[8,0],[24,2],[28,0],[36,2],[40,5],[44,12],[48,31],[52,8],[56,2],[60,2],[64,2],[68,0],[72,100],[76,60],[80,3],[84,5],[88,2],[92,64],[96,2],[100,255]]:
		var invalid := packet()
		invalid.encode_u32(pair[0],pair[1])
		check(not state.apply(invalid,{"epoch":3}).is_empty(),"Invalid save accepted: "+str(pair))
	check(not state.apply(packet().slice(0,-1),{"epoch":3}).is_empty(),"Truncated save accepted")
	check(state.pending.entries[0].location=="Dock","Rejected save mutated state")
	check(state.present(4).is_empty(),"Save survived epoch change")
	var hello := PackedByteArray()
	hello.resize(40)
	for pair in [[0,0x3152474d],[4,15],[8,22],[12,20],[16,16777215],[20,16777215]]: hello.encode_u32(pair[0],pair[1])
	var gate := preload("res://session_gate.gd").new()
	gate.capabilities=16777215
	gate.configure_token("00".repeat(16))
	check(gate.accept(1,hello).is_empty() and gate.accept(24,PackedByteArray()).is_empty(),"Save negotiation failed")
	gate=preload("res://session_gate.gd").new()
	gate.capabilities=16777215
	gate.configure_token("00".repeat(16))
	hello.encode_u32(8,21)
	check(not gate.accept(1,hello).is_empty(),"Old minor accepted save UI")

func relocate(workspace: RefCounted) -> Dictionary:
	var exporter := preload("res://addons/mgs_editor/mod_export.gd").new()
	var path: String = workspace.root.path_join("saves.zip")
	check(exporter.export_mod(workspace.root.path_join("mod.json"),path).is_empty(),exporter.error)
	var zip := ZIPReader.new()
	check(zip.open(path)==OK,"Cannot open save ZIP")
	var installed: String = workspace.root.path_join("relocated")
	var files := Array(zip.get_files()).filter(func(file):return not file.ends_with("/"))
	check(files.size()==3,"Unexpected save UI dependencies: "+str(files))
	for file in files:
		check(file.get_extension() in ["gd","tscn","json"],"Original data in save ZIP")
		var target := installed.path_join(str(file))
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		FileAccess.open(target,FileAccess.WRITE).store_buffer(zip.read_file(file))
	zip.close()
	var registry := preload("res://mod_registry.gd").new()
	check(registry.configure({},[installed.path_join("mod.json")]).is_empty(),"Relocated saves rejected")
	return registry.ui

func run() -> void:
	state_checks()
	var directory := ProjectSettings.globalize_path("res://../../../.local/godot-content")
	var catalog = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("catalog.json")))
	var workspace := preload("res://addons/mgs_editor/mod_workspace.gd").new()
	workspace.root="user://save-test-%d"%Time.get_ticks_usec()
	var authoring := preload("res://addons/mgs_editor/ui_authoring.gd").new()
	var path := authoring.open_ui(workspace,directory,catalog.assets,1,"save_load")
	check(not path.is_empty(),"Cannot author save UI: "+authoring.error)
	if path.is_empty():
		quit(1)
		return
	var scene := load(path).instantiate() as Control
	root.add_child(scene)
	scene.get_node("Title").position+=Vector2(3,2)
	scene.get_node("Dialog/Cancel").position.x-=4
	var packed := PackedScene.new()
	check(packed.pack(scene)==OK and ResourceSaver.save(packed,path)==OK,"Cannot save authored dialog")
	var viewport := SubViewport.new()
	viewport.size=Vector2i(960,672)
	root.add_child(viewport)
	var presenter := preload("res://save_presenter.gd").new()
	viewport.add_child(presenter)
	check(presenter.initialize(relocate(workspace),directory,catalog.assets,1).is_empty(),"Cannot initialize relocated saves")
	presenter.fit_screen(Rect2(0,0,960,672))
	presenter.state.session_id.resize(16)
	presenter.state.session_id.fill(7)
	check(presenter.state.apply(packet(),{"epoch":3}).is_empty(),"Cannot apply save packet")
	presenter.present(3,true)
	check(presenter.ui.get_node("Title").position==Vector2(29,26),"Authored placement lost")
	check(presenter.ui.get_node("Dialog/Cancel").position.x==126,"Authored button placement lost")
	for name in ["Confirm","Cancel","Continue"]:
		var button: Button = presenter.ui.get_node("Dialog/"+name)
		check(button.position.y+button.size.y<58,"Button resized during original-free round trip")
	check(presenter.ui.get_node("SaveList/Save0/Details").text=="01:24   /   Normal","Wrong save details")
	var state: Dictionary = presenter.state.current.duplicate(true)
	state.state=2
	presenter.ui.apply_native_state(state)
	check(presenter.ui.get_node("Dialog/Choices").text.contains("[ CANCEL ]"),"Overwrite defaults to destructive choice")
	state.state=0
	state.loading=1
	state.can_create=0
	presenter.ui.apply_native_state(state)
	check(not presenter.ui.get_node("NewSave").visible,"Load screen offers New Save")
	if DisplayServer.get_name() != "headless":
		for tick in 3:
			viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
			await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		DirAccess.make_dir_recursive_absolute("res://.generated/save-ui")
		check(image.save_png("res://.generated/save-ui/dialog.png")==OK,"Cannot save rendered dialog")
		check(image.get_pixel(170,160).get_luminance()>0.05,"Save row highlight missing")
	presenter.present(4,true)
	check(not presenter.visible,"Stale save dialog visible")
	scene.free()
	viewport.free()
	print("MGS_SAVE_UI_TEST failures=%d"%failures)
	quit(1 if failures else 0)
