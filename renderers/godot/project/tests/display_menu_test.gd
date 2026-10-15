extends SceneTree

class Provider extends Node:
	signal settings_updated(snapshot: Dictionary)
	signal request_finished(id: int, error: String)
	var display: Node
	var unavailable_reason := ""
	var last_error := ""
	var requests: Array = []
	var snapshot := {"saved":{}, "definitions":[{"id":"display.resolution", "choices":["640x480","1280x720"]}]}
	func get_snapshot() -> Dictionary:
		return {"applied":display.applied, "live_apply":display.supported, "definitions":snapshot.definitions}
	func request(action: String, values: Dictionary = {}) -> int:
		requests.append([action, values.duplicate()])
		return requests.size()
	func finish(error: String = "") -> void:
		settings_updated.emit(get_snapshot())
		request_finished.emit(requests.size(), error)

var failures := 0
var serial := 0
var store := Provider.new()
var display := preload("res://display_settings.gd").new()
var menu := preload("res://display_menu.gd").new()
var options: Control
var actions := preload("res://options_actions.gd").new()
var action_id := 0
var options_state := {"active":true,"epoch":3,"generation":7,"revision":1,"selection":1,"vibration":1,"controller_row":0,"controller_type":0,"reverse":0,"values":[0,0,1,0,0,0,0,0]}
var original := {"display.resolution":"640x480","display.widescreen":false,"display.fullscreen":false}
var desired := {"display.resolution":"1280x720","display.widescreen":true,"display.fullscreen":true}

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _initialize() -> void: run.call_deferred()

func exchange(values: Dictionary) -> void:
	var size: Vector2i = preload("res://display_surface.gd").extent(values)
	var packet := PackedInt32Array([1,serial,0,1,0,0,0,0,size.x,size.y,int(values["display.widescreen"]),0]).to_byte_array()
	var response: Dictionary = await display.exchange(packet)
	check(not response.has("error"), "Invalid display exchange: " + str(response))
	if response.has("reply") and response.reply.decode_u32(4): serial = response.reply.decode_u32(4)

func relocate(workspace: RefCounted) -> Dictionary:
	var exporter := preload("res://addons/mgs_editor/mod_export.gd").new()
	var path: String = workspace.root.path_join("display.zip")
	check(exporter.export_mod(workspace.root.path_join("mod.json"),path).is_empty(),exporter.error)
	var zip := ZIPReader.new()
	check(zip.open(path)==OK,"Cannot open display ZIP")
	var installed: String = workspace.root.path_join("relocated")
	var files := Array(zip.get_files()).filter(func(file):return not file.ends_with("/"))
	check(files.size()==3,"Unexpected display UI dependencies: "+str(files))
	for file in files:
		check(file.get_extension() in ["gd","tscn","json"],"Original data in display ZIP")
		var target := installed.path_join(str(file))
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		FileAccess.open(target,FileAccess.WRITE).store_buffer(zip.read_file(file))
	zip.close()
	var registry := preload("res://mod_registry.gd").new()
	check(registry.configure({},[installed.path_join("mod.json")]).is_empty(),"Relocated display UI rejected")
	return registry.ui

func open_key() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_F10
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func render_options() -> void:
	var view := options_state.duplicate(true)
	view.elements=[]
	view.texts={}
	var layout := preload("res://options_layout.gd")
	for index in layout.ELEMENTS.size():
		var item: Array = layout.ELEMENTS[index]
		view.elements.append({"texture":layout.texture_id(item[1]),"position":item[2].position,"size":item[2].size,"rgb":0x808080,"layer":1 if index<27 else 0,"blend":0})
	options.apply_native_state(view)

func enter_options_page(controller: bool = false) -> void:
	var button: Button = options.get_node("Options/Screen/Interact")
	button.grab_focus()
	if controller:
		for down in [true,false]:
			var event := InputEventJoypadButton.new()
			event.button_index = JOY_BUTTON_B
			event.pressed = down
			Input.parse_input_event(event)
			await process_frame
	else: button.pressed.emit()
	var packet := PackedInt32Array([1,3,0,0,0,0,action_id,2 if action_id else 0]).to_byte_array()
	var response: PackedByteArray = actions.exchange(packet).reply
	check(response.decode_u32(20)==1 and response.decode_u32(24)==6,"Display did not select its native Options row")
	action_id = response.decode_u32(4)
	packet.encode_u32(24,action_id)
	packet.encode_u32(28,2)
	actions.exchange(packet)
	options_state.selection=6
	options_state.revision+=1
	render_options()
	actions.present(options_state)
	await process_frame

func preview() -> void:
	menu.ui.get_node("Panel/Resolution").select(1)
	menu.ui.get_node("Panel/Widescreen").button_pressed = true
	menu.ui.get_node("Panel/Fullscreen").button_pressed = true
	menu.ui.get_node("Panel/Preview").pressed.emit()
	check(display.phase == "validating" and menu.captured, "Preview did not validate while capturing input")
	store.finish()
	await exchange(original)
	await exchange(desired)
	check(display.phase == "preview", "Menu preview not applied")
	check(menu.ui.get_node("Panel/Revert").has_focus(), "Preview did not default to Revert")
	check(menu.ui.get_node("Panel/Status").text.contains("Reverting in"), "Missing countdown")

func render_image() -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://.generated/display-menu")
	check(image.save_png("res://.generated/display-menu/preview.png")==OK, "Cannot save display panel image")

func run() -> void:
	root.add_child(store)
	root.add_child(display)
	display.configure(store, preload("res://tests/display_settings_test.gd").Surface.new())
	store.display = display
	display.session_id.resize(16)
	await exchange(original)
	var directory := ProjectSettings.globalize_path("res://../../../.local/godot-content")
	var catalog = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("catalog.json")))
	var workspace := preload("res://addons/mgs_editor/mod_workspace.gd").new()
	workspace.root = "user://display-menu-test-%d" % Time.get_ticks_usec()
	var authoring := preload("res://addons/mgs_editor/ui_authoring.gd").new()
	var path := authoring.open_ui(workspace,directory,catalog.assets,int(catalog.disc),"display_settings")
	check(not path.is_empty(), "Cannot author display UI: " + authoring.error)
	if path.is_empty():
		quit(1)
		return
	var authored: Control = load(path).instantiate()
	var session: Node = authoring.attach(authored, directory, catalog.assets, int(catalog.disc))
	check(authoring.error.is_empty(), "Editor binding failed")
	authored.get_node("Panel/Title").position += Vector2(3,2)
	session.prepare_save()
	var packed := PackedScene.new()
	check(packed.pack(authored)==OK and ResourceSaver.save(packed,path)==OK, "Cannot save display edits")
	authored.free()
	root.add_child(menu)
	var error := menu.initialize(relocate(workspace),directory,catalog.assets,int(catalog.disc),store)
	check(error.is_empty(), "Cannot initialize display menu: " + error)
	if not error.is_empty():
		quit(1)
		return
	var builder := preload("res://options_scene.gd").new()
	options = builder.create(menu.resources)
	root.add_child(options)
	options.bind_originals(menu.resources)
	root.add_child(actions)
	actions.session_id.resize(16)
	actions.supported=true
	options.connect_provider(actions)
	menu.ui.capture_changed.connect(actions.suspend_input)
	options.get_node("Options/Screen/Interact").text = "VIDEO"
	check(menu.register_options(options).is_empty(),"Display did not register in Options")
	check(options.get_node("Options/Screen/Interact").text == "VIDEO","Registration overwrote an authored entry label")
	render_options()
	actions.present(options_state)
	menu.fit_screen(Rect2(0,0,960,672))
	check(menu.ui.get_node("Panel/Title").position == Vector2(27,22), "Authored layout lost")
	check(menu.ui.get_node("Panel/Keep").get_rect().end.y < menu.ui.get_node("Panel/Hint").position.y, "Buttons overlap footer")
	await open_key()
	check(not menu.captured, "Unnegotiated menu captured input")
	menu.ui.allow_capture(true)
	check(menu.ui.get_node_or_null("Entry")==null,"Global Display entry still exists")
	check(not menu.ui.get_node("Panel/Close").is_visible_in_tree(),"Back visible outside Display")
	await open_key()
	check(not menu.captured,"F10 opened Display outside its Options entry")
	await enter_options_page()
	check(menu.captured and menu.buttons(65535)==0x40000000, "Menu leaked native keyboard buttons")
	check(menu.ui.get_node("Panel/Resolution").get_item_text(0)=="640x480", "Resolution choices absent")
	await preview()
	await render_image()
	menu.ui.close_menu()
	check(display.phase == "rollback_queued" and menu.captured, "Close released capture before reverting")
	await exchange(desired)
	await exchange(original)
	check(display.applied == original and store.requests.size()==1, "Cancel saved a display change")
	await preview()
	display.deadline_msec = 0
	display._process(0)
	await exchange(desired)
	await exchange(original)
	check(display.applied == original and menu.ui.get_node("Panel/Status").text.contains("timed out"), "Timeout did not restore display with feedback")
	await preview()
	menu.ui.get_node("Panel/Keep").pressed.emit()
	check(store.requests[-1]==["save",desired], "Keep did not save candidate")
	store.snapshot.saved = desired.duplicate()
	store.finish()
	await process_frame
	check(display.phase=="idle", "Keep did not finish")
	menu.ui.get_node("Panel/Close").pressed.emit()
	check(options.get_node("Options/Screen/Interact").has_focus(),"Back did not restore Display entry focus")
	check(not menu.ui.get_node("Panel/Close").is_visible_in_tree(),"Back visible after closing Display")
	check(not menu.captured and menu.buttons(65535,actions.captures_input())==0x40000000, "Options did not regain input")
	actions.present({})
	check(not menu.captured and menu.buttons(65535)==0, "Closing leaked held keyboard input")
	check(menu.buttons(0)==0 and menu.buttons(65535)==65535, "Released input did not resume")
	var controller := InputEventJoypadButton.new()
	controller.button_index = JOY_BUTTON_RIGHT_STICK
	controller.pressed = true
	Input.parse_input_event(controller)
	await process_frame
	check(not menu.captured, "R3 opened Display outside Options")
	controller = controller.duplicate()
	controller.pressed = false
	Input.parse_input_event(controller)
	await process_frame
	render_options()
	actions.present(options_state)
	await enter_options_page(true)
	check(menu.captured,"Controller did not enter Display from Options")
	var focus := root.gui_get_focus_owner()
	var direction := InputEventJoypadButton.new()
	direction.button_index = JOY_BUTTON_DPAD_UP
	direction.pressed = true
	Input.parse_input_event(direction)
	await process_frame
	check(root.gui_get_focus_owner() != focus, "Controller direction did not navigate settings")
	menu.ui.close_menu()
	check(menu.select_disc(int(catalog.disc)).is_empty(), "Current disc lost fonts")
	options.free()
	actions.free()
	menu.free()
	display.free()
	store.free()
	print("MGS_DISPLAY_MENU_TEST failures=%d" % failures)
	quit(1 if failures else 0)
