extends SceneTree

var failures := 0

class NameReference extends Node2D:
	var font: Font
	var text := ""
	var right := 306.0
	func _draw() -> void:
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		draw_string(font, Vector2(right - width, font.get_ascent(8)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func frame(viewport: SubViewport) -> Image:
	for _tick in 3:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func bright_pixels(image: Image, rect: Rect2i) -> int:
	var count := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if image.get_pixel(x,y).v > 0.5: count += 1
	return count

func run() -> void:
	var directory := ProjectSettings.globalize_path("res://../../../.local/godot-content")
	var catalog = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("catalog.json")))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640,448)
	viewport.world_3d = World3D.new()
	root.add_child(viewport)
	viewport.add_child(Camera3D.new())
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.08,0.12,0.15)
	viewport.world_3d.environment = environment
	var fsr2 := "--fsr2" in OS.get_cmdline_user_args()
	if fsr2:
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
		viewport.scaling_3d_scale = 0.667
	var presenter := preload("res://inventory_presenter.gd").new()
	viewport.add_child(presenter)
	var error := presenter.initialize({},directory,catalog.assets,int(catalog.disc))
	check(error.is_empty(), "Cannot initialize inventory: " + error)
	if not error.is_empty():
		viewport.free()
		quit(1)
		return
	presenter.fit_screen(Rect2(0,0,640,448))
	presenter.state.session_id.resize(16)
	presenter.state.session_id.fill(7)
	var fixture := preload("res://tests/inventory_ui_test.gd").new()
	check(presenter.state.apply(fixture.packet(), {"epoch":3}).is_empty(), "Cannot apply native inventory")
	presenter.present(3,true)
	var image := await frame(viewport)
	check(bright_pixels(image,Rect2i(32,368,94,60)) > 100, "Item artwork/counter missing")
	check(bright_pixels(image,Rect2i(32,300,94,60)) > 100, "Carousel card missing")
	check(bright_pixels(image,Rect2i(520,368,94,60)) > 100, "Weapon artwork/magazine missing")
	var output := "res://.generated/inventory-gpu-test"
	check(DirAccess.make_dir_recursive_absolute(output) == OK, "Cannot create evidence folder")
	check(image.save_png(output.path_join("inventory-%s.png" % ("fsr2" if fsr2 else "native"))) == OK, "Cannot save inventory evidence")
	presenter.ui.preview_mode = 1
	presenter.ui.update_preview()
	var description := await frame(viewport)
	check(bright_pixels(description,Rect2i(172,144,400,160)) > 200, "Original description preview font missing")
	check(description.save_png(output.path_join("description-%s.png" % ("fsr2" if fsr2 else "native"))) == OK, "Cannot save description evidence")
	await name_alignment(viewport, presenter)
	presenter.state.apply(fixture.packet(false), {"epoch":3})
	presenter.present(3,true)
	var hidden := await frame(viewport)
	check(bright_pixels(hidden,Rect2i(32,368,94,60)) == 0, "Inventory survived hidden frame")
	fixture.free()
	viewport.free()
	print("MGS_INVENTORY_RENDER_TEST failures=%d" % failures)
	quit(1 if failures else 0)

func name_alignment(viewport: SubViewport, presenter: Control) -> void:
	var reference_view := SubViewport.new()
	reference_view.size = Vector2i(640, 16)
	root.add_child(reference_view)
	var reference := NameReference.new()
	reference.font = presenter.ui._art.font
	reference.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	reference.scale = Vector2(2, 2)
	reference_view.add_child(reference)
	for side in 2:
		var panel := {"side": side, "id": 0, "position": Vector2(16 if side == 0 else 260, 184), "icon": 1,
			"flags": 0, "quantity": 0, "maximum": 0, "level": 0, "magazine": 0, "magazine_max": 0, "burst": 0}
		reference.right = panel.position.x + 46
		for name in ["STINGER", "BODY ARMOR", "I", "MP 5 SD", "NO ITEM", "PSG1", "SOCOM"]:
			panel.name = name
			presenter.ui.apply_native_state({"panels": [panel]})
			reference.text = name
			reference.queue_redraw()
			var actual := await frame(viewport)
			var expected := await frame(reference_view)
			if side == 1 and name == "SOCOM":
				actual.save_png("res://.generated/inventory-gpu-test/name-actual.png")
				expected.save_png("res://.generated/inventory-gpu-test/name-reference.png")
			var different := 0
			for y in 12:
				for x in range(maxi(0, int(reference.right - 80) * 2), mini(640, int(reference.right + 8) * 2)):
					if (actual.get_pixel(x, y + 412).v > 0.5) != (expected.get_pixel(x, y).v > 0.5): different += 1
			check(different == 0, "Inventory name differs from native right anchor: side=%d text=%s pixels=%d" % [side, name, different])
			var title: Label = presenter.ui.get_node("Item/Name" if side == 0 else "Weapon/Name")
			check(is_equal_approx(title.position.x + title.size.x, 46), "Inventory label drifted with native text")
	reference_view.free()
