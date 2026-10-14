extends Control

const Assets = preload("res://original_ui_assets.gd")
var resources := Assets.new()
var state: RefCounted
var ui: Control
var disc := 0
var slot := ""
var builder_script: Script

func initialize(overrides: Dictionary, directory: String, catalog: Dictionary, source_disc: int) -> String:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resources.configure(directory, catalog, source_disc)
	disc = source_disc
	if overrides.has(slot):
		var packed := load(overrides[slot].scene) as PackedScene
		if packed == null: return "Cannot load UI scene"
		var instance := packed.instantiate()
		if not instance is Control:
			instance.free()
			return "UI scene requires a Control root"
		ui = instance
	else:
		var builder: RefCounted = builder_script.new()
		ui = builder.create(resources)
		if ui == null: return builder.error
	add_child(ui)
	if not ui.has_method("apply_native_state"): return "UI requires apply_native_state(state)"
	var error := bind_originals()
	visible = false
	return error

func bind_originals() -> String:
	return ui.call("bind_originals", resources) if ui.has_method("bind_originals") else ""

func select_disc(source_disc: int) -> String:
	if source_disc == disc: return ""
	if ui.has_method("detach_originals"): ui.call("detach_originals")
	disc = source_disc
	resources.configure(resources.root, resources.assets, disc)
	return bind_originals()

func present(epoch: int, display_enabled: bool) -> void:
	if ui == null: return
	var previous: Dictionary = state.current
	var snapshot: Dictionary = state.present(epoch)
	visible = display_enabled and snapshot.get("active", false)
	if snapshot != previous: ui.call("apply_native_state", snapshot)

func fit_screen(rect: Rect2) -> void:
	position = rect.position
	size = rect.size
	if ui != null: ui.scale = rect.size / Vector2(320, 224)
