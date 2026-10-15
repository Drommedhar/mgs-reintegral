@tool
extends Control

signal capture_changed(active: bool)

var provider: Node
var opened := false
var capture_available := false
var _phase := ""
var _message := ""
var options_available := false
var _preview_visibility: Dictionary = {}
var _last_applied: Dictionary = {}

func bind_originals(resources: RefCounted) -> String:
	if theme.default_font == null or theme.default_font.has_meta("mgs_retail_derived"):
		var font: Font = resources.font("mgs/ui/menu_small")
		if font == null: return resources.error
		theme.default_font = font
	return ""

func detach_originals() -> void:
	for path in _preview_visibility: get_node(path).visible = _preview_visibility[path]
	_preview_visibility.clear()
	if theme.default_font != null and theme.default_font.has_meta("mgs_retail_derived"):
		theme.default_font = null

func _ready() -> void:
	if Engine.is_editor_hint(): return
	for pair in [["Panel/Close",close_menu],["Panel/Preview",preview],
		["Panel/Keep",confirm],["Panel/Revert",revert]]:
		get_node(pair[0]).pressed.connect(pair[1])
	get_node("Panel").hide()

func connect_provider(value: Node) -> void:
	provider = value
	provider.settings_updated.connect(_settings_updated)
	provider.display.changed.connect(_display_changed)
	provider.display.finished.connect(_finished)

func allow_capture(available: bool) -> void:
	capture_available = available

func allow_options(available: bool) -> void:
	options_available = available

func open_menu() -> void:
	if not capture_available or not options_available or opened: return
	opened = true
	_message = ""
	_last_applied = {}
	get_node("Panel").show()
	capture_changed.emit(true)
	_settings_updated(provider.get_snapshot())
	get_node("Panel/Close").grab_focus()

func close_menu() -> void:
	if not opened: return
	if provider.display.phase == "preview":
		revert()
		return
	if provider.display.phase != "idle": return
	opened = false
	get_node("Panel").hide()
	get_viewport().gui_release_focus()
	capture_changed.emit(false)

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or provider == null: return
	if opened and event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()

func _settings_updated(snapshot: Dictionary) -> void:
	if not opened: return
	_sync_fields(snapshot)
	_display_changed(provider.display.snapshot())

func _sync_fields(snapshot: Dictionary) -> void:
	var values: Dictionary = snapshot.get("applied", {})
	if values == _last_applied: return
	_last_applied = values.duplicate()
	var choices: Array = []
	for definition in snapshot.get("definitions", []):
		if definition.id == "display.resolution": choices = definition.get("choices", []).duplicate()
	var current: String = values.get("display.resolution", "")
	if not current.is_empty() and current not in choices: choices.append(current)
	var resolution: OptionButton = get_node("Panel/Resolution")
	resolution.clear()
	for choice in choices: resolution.add_item(choice)
	if current in choices: resolution.select(choices.find(current))
	get_node("Panel/Widescreen").set_pressed_no_signal(values.get("display.widescreen",false))
	get_node("Panel/Fullscreen").set_pressed_no_signal(values.get("display.fullscreen",false))

func _display_changed(state: Dictionary) -> void:
	if not opened: return
	_sync_fields(provider.get_snapshot())
	var phase: String = state.phase
	var idle := phase == "idle"
	var ready: bool = provider.get_snapshot().get("live_apply", false)
	for name in ["Resolution", "Widescreen", "Fullscreen", "Preview"]:
		get_node("Panel/"+name).disabled = not idle or not ready
	get_node("Panel/Close").disabled = not idle
	for name in ["Keep", "Revert"]:
		get_node("Panel/"+name).visible = phase == "preview"
	for name in ["Preview", "Close"]:
		get_node("Panel/"+name).visible = phase != "preview"
	if phase == "preview" and _phase != phase: get_node("Panel/Revert").grab_focus()
	elif idle and _phase != phase: get_node("Panel/Close").grab_focus()
	_phase = phase
	if not state.error.is_empty(): _message = state.error
	if not ready: _message = provider.unavailable_reason if not provider.unavailable_reason.is_empty() else "Waiting for display settings..."
	get_node("Panel/Status").text = _message if idle else "Applying display settings..."
	_process(0)

func _process(_delta: float) -> void:
	if provider != null and opened and provider.display.phase == "preview":
		get_node("Panel/Status").text = "KEEP THESE SETTINGS?\nReverting in %d seconds" % ceili(provider.display.snapshot().remaining_seconds)

func _finished(result: String, error: String) -> void:
	_message = error if not error.is_empty() else {"confirmed":"Display settings saved.","reverted":"Previous display restored."}.get(result, "Display change rejected.")
	_settings_updated(provider.get_snapshot())

func preview() -> void:
	var resolution: OptionButton = get_node("Panel/Resolution")
	if resolution.selected < 0: return
	_message = provider.display.preview({"display.resolution":resolution.get_item_text(resolution.selected),
		"display.widescreen":get_node("Panel/Widescreen").button_pressed,
		"display.fullscreen":get_node("Panel/Fullscreen").button_pressed})
	_display_changed(provider.display.snapshot())

func confirm() -> void:
	_message = provider.display.confirm()
	_display_changed(provider.display.snapshot())

func revert() -> void:
	_message = provider.display.revert()
	_display_changed(provider.display.snapshot())

func update_preview() -> void:
	if _preview_visibility.is_empty():
		for path in ["Panel", "Panel/Keep", "Panel/Revert"]:
			_preview_visibility[path] = get_node(path).visible
	get_node("Panel").show()
	get_node("Panel/Keep").hide()
	get_node("Panel/Revert").hide()
	var resolution: OptionButton = get_node("Panel/Resolution")
	resolution.clear()
	resolution.add_item("1920x1080")
	get_node("Panel/Status").text = "Preview changes, then keep or revert."
