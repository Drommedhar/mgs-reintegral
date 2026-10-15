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
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func run() -> void:
	var directory := ProjectSettings.globalize_path("res://../../../.local/godot-content")
	var catalog = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("catalog.json")))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640,448)
	root.add_child(viewport)
	var presenter := preload("res://title_presenter.gd").new()
	viewport.add_child(presenter)
	var error := presenter.initialize({},directory,catalog.assets,int(catalog.disc))
	check(error.is_empty(),"Cannot initialize title: "+error)
	if not error.is_empty():
		viewport.free()
		quit(1)
		return
	presenter.fit_screen(Rect2(0,0,640,448))
	presenter.show()
	var output := "res://.generated/title-gpu-test"
	DirAccess.make_dir_recursive_absolute(output)
	for page in 4:
		presenter.ui.preview_page = page
		presenter.ui.update_preview()
		var image := await render(viewport)
		check(image.save_png(output.path_join("page%d.png"%page))==OK,"Cannot save title preview")
		check(image.get_used_rect().has_area(),"Title preview is empty")
	presenter.hide()
	var art := preload("res://title_art.gd").new()
	art.native_rect = Rect2(10,10,32,32)
	art.position = art.native_rect.position
	art.size = art.native_rect.size
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var source := Image.create(2,1,false,Image.FORMAT_RGBA8)
	source.set_pixel(0,0,Color(0.5,0.5,0.5,1))
	source.set_pixel(1,0,Color(1,0,0,1))
	art.texture = ImageTexture.create_from_image(source)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(art)
	var element := {"position":Vector2(10,10),"size":Vector2(32,32),"layer":1,"source":Rect2(0,0,1,1),"top_rgb":0x808080,"bottom_rgb":0x808080}
	art.apply_element(element,{})
	var image := await render(viewport)
	check(absf(image.get_pixel(25,25).r-0.5)<0.02,"Title shader multiplies artwork twice")
	element.source = Rect2(1,0,1,1)
	art.apply_element(element,{})
	image = await render(viewport)
	check(image.get_pixel(25,25).r>0.98 and image.get_pixel(25,25).g<0.01,"Native texture crop ignored")
	element.source = Rect2(0,0,1,1)
	element.bottom_rgb = 0
	art.apply_element(element,{})
	image = await render(viewport)
	check(image.get_pixel(25,12).r>image.get_pixel(25,39).r+0.35,"Native menu gradient missing")
	element.bottom_rgb = 0x808080
	element.blend = 1
	art.apply_element(element,{})
	image = await render(viewport)
	check(absf(image.get_pixel(25,25).r-0.25)<0.025,"Native half-blend incorrect")
	viewport.free()
	print("MGS_TITLE_RENDER_TEST failures=%d"%failures)
	quit(1 if failures else 0)
