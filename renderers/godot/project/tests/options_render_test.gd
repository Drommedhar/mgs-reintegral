extends SceneTree

var failures := 0
func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func render(viewport: SubViewport) -> Image:
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
	var presenter := preload("res://options_presenter.gd").new()
	viewport.add_child(presenter)
	var error := presenter.initialize({},directory,catalog.assets,int(catalog.disc))
	check(error.is_empty(),error)
	if not error.is_empty():
		viewport.free()
		quit(1)
		return
	presenter.fit_screen(Rect2(0,0,640,448))
	presenter.state.session_id.resize(16)
	presenter.state.session_id.fill(7)
	var fixture := preload("res://tests/options_ui_test.gd").new()
	check(presenter.state.apply(fixture.packet(),{"epoch":3}).is_empty(),"Options packet rejected")
	presenter.present(3,true)
	var image := await render(viewport)
	var white := 0
	for y in range(378,388):
		for x in range(24,60):
			var pixel := image.get_pixel(x,y)
			if pixel.r>0.9 and pixel.g>0.9 and pixel.b>0.9: white+=1
	check(white>=60,"Native Options help glyph missing")
	var path := "res://.generated/options-gpu-test"
	DirAccess.make_dir_recursive_absolute(path)
	check(image.save_png(path.path_join("options.png"))==OK,"Cannot save Options image")
	presenter.ui.get_node("Selection").hide()
	var without_focus := await render(viewport)
	var highlight_pixels := 0
	for y in range(92,140):
		for x in range(208,432):
			if image.get_pixel(x,y).get_luminance()>without_focus.get_pixel(x,y).get_luminance()+0.05: highlight_pixels+=1
	check(highlight_pixels>100,"Options selection highlight missing")
	presenter.ui.get_node("Selection").show()
	for page in [1,2]:
		presenter.ui.preview_page=page
		presenter.ui.update_preview()
		image=await render(viewport)
		check(image.save_png(path.path_join("page%d.png"%page))==OK,"Cannot save Options page")
	presenter.present(4,true)
	check(not presenter.visible,"Old Options visible")
	fixture.free()
	viewport.free()
	print("MGS_OPTIONS_RENDER_TEST failures=%d"%failures)
	quit(1 if failures else 0)
