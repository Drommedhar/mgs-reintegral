extends Control

var ui: Control
var resources := preload("res://original_ui_assets.gd").new()
var disc := 0
var _keys_released := true

func initialize(overrides: Dictionary, directory: String, catalog: Dictionary, source_disc: int, provider: Node) -> String:
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resources.configure(directory, catalog, source_disc)
	disc = source_disc
	if overrides.has("display_settings"):
		var packed := load(overrides.display_settings.scene) as PackedScene
		if packed == null: return "Cannot load display settings UI"
		var instance := packed.instantiate()
		if not instance is Control:
			instance.free()
			return "Display settings UI requires a Control root"
		ui = instance
	else:
		var builder := preload("res://display_menu_scene.gd").new()
		ui = builder.create(resources)
		if ui == null: return builder.error
	for method in ["connect_provider", "allow_capture", "allow_options", "open_menu", "close_menu"]:
		if not ui.has_method(method): return "Display settings UI requires " + method
	if not ui.has_signal("capture_changed"): return "Display settings UI requires capture_changed"
	add_child(ui)
	ui.capture_changed.connect(func(active: bool):
		captured = active
		if active: _keys_released = false)
	ui.connect_provider(provider)
	return ui.bind_originals(resources) if ui.has_method("bind_originals") else ""

func register_options(options_ui: Control) -> String:
	if not options_ui.has_method("register_page"):
		return "Options UI must implement register_page to expose Display settings"
	return options_ui.register_page(6,"DISPLAY",ui)

var captured := false

func buttons(raw: int, other_capture: bool = false) -> int:
	if captured or other_capture:
		_keys_released = false
		return 0x40000000
	if raw == 0: _keys_released = true
	return raw if _keys_released else 0

func select_disc(source_disc: int) -> String:
	if ui == null or disc == source_disc: return ""
	if ui.has_method("detach_originals"): ui.detach_originals()
	disc = source_disc
	resources.configure(resources.root, resources.assets, disc)
	return ui.bind_originals(resources) if ui.has_method("bind_originals") else ""

func fit_screen(rect: Rect2) -> void:
	position = rect.position
	size = rect.size
	if ui != null: ui.scale = rect.size / Vector2(320,224)
