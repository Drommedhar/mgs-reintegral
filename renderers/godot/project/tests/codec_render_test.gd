extends SceneTree

var failures := 0
func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func image(viewport: SubViewport) -> Image:
	for tick in 3:
		viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func run() -> void:
	var directory := ProjectSettings.globalize_path("res://../../../.local/godot-content")
	var catalog = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("catalog.json")))
	var viewport := SubViewport.new()
	viewport.size=Vector2i(640,448)
	root.add_child(viewport)
	var presenter := preload("res://codec_presenter.gd").new()
	viewport.add_child(presenter)
	var error := presenter.initialize({},directory,catalog.assets,int(catalog.disc))
	check(error.is_empty(),"Cannot initialize Codec: "+error)
	if not error.is_empty():
		viewport.free()
		quit(1)
		return
	presenter.fit_screen(Rect2(0,0,640,448))
	presenter.state.session_id.resize(16)
	presenter.state.session_id.fill(7)
	var fixture := preload("res://tests/codec_ui_test.gd").new()
	check(presenter.state.apply(fixture.packet(),{"epoch":3}).is_empty(),"Codec frame rejected")
	presenter.present(3,true)
	var rendered := await image(viewport)
	check(rendered.get_pixel(70,70).r>0.9 and rendered.get_pixel(130,70).b>0.9,"Left portrait pixels missing")
	check(rendered.get_pixel(490,70).g>0.9,"Right portrait missing")
	var lit_digit := rendered.get_pixel(293,166)
	var dim_digit := rendered.get_pixel(283,166)
	check(lit_digit.g>0.8 and lit_digit.g>dim_digit.g*2.5,"Active frequency foreground missing")
	check(absf(dim_digit.g-66.0/255.0)<0.02,"Inactive digit background missing")
	check(rendered.get_pixel(246,188).g>0.8 and rendered.get_pixel(246,106).g<0.3,"Signal foreground does not follow native level")
	var output := "res://.generated/codec-gpu-test"
	DirAccess.make_dir_recursive_absolute(output)
	check(rendered.save_png(output.path_join("conversation.png"))==OK,"Cannot save Codec image")
	var state: Dictionary = presenter.state.pending.duplicate(true)
	state.signal=0
	presenter.ui.apply_native_state(state)
	var no_signal := await image(viewport)
	check(absf(no_signal.get_pixel(246,188).g-66.0/255.0)<0.02,"Zero signal lost background or retained foreground")
	state.signal=8
	state.images[1].fill(0)
	state.faces[0].previous_weight=64
	presenter.ui.apply_native_state(state)
	var faded := await image(viewport)
	check(absf(faded.get_pixel(90,120).r-0.5)<0.05,"Portrait crossfade weight wrong")
	presenter.ui.preview_mode=3
	presenter.ui.update_preview()
	var call := await image(viewport)
	check(call.save_png(output.path_join("incoming.png"))==OK,"Cannot save incoming image")
	presenter.ui.preview_mode=2
	presenter.ui.update_preview()
	var contacts := await image(viewport)
	check(contacts.save_png(output.path_join("contacts.png"))==OK,"Cannot save contacts image")
	presenter.present(4,true)
	check(not presenter.visible,"Old Codec still visible")
	fixture.free()
	viewport.free()
	print("MGS_CODEC_RENDER_TEST failures=%d"%failures)
	quit(1 if failures else 0)
