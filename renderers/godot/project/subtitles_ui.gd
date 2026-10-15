@tool
extends Control

signal native_state_changed(state: Dictionary)

@export var preview_text := "Snake, do you read me?":
	set(value):
		preview_text = value
		if Engine.is_editor_hint(): update_preview.call_deferred()
func bind_originals(resources: RefCounted) -> String:
	resources.bind_dialogue_fonts(self)
	var font: Font = resources.font("mgs/ui/subtitle")
	if font == null: return resources.error
	get_node("Text").preview_font = font
	var pause_font: Font = resources.font("mgs/ui/menu_large")
	if pause_font == null: return resources.error
	var label := get_node("Pause") as Label
	if not label.has_theme_font_override("font") or label.get_theme_font("font").get_meta("mgs_retail_derived", false):
		label.add_theme_font_override("font", pause_font)
	return ""

func detach_originals() -> void:
	get_node("Text").detach_originals()
	var label := get_node("Pause") as Label
	if label.has_theme_font_override("font") and label.get_theme_font("font").get_meta("mgs_retail_derived", false):
		label.remove_theme_font_override("font")
	get_node("Pause").hide()
	get_node("Dim").hide()

func update_preview() -> void:
	get_node("Text").preview_text = preview_text
	get_node("Text").queue_redraw()

func apply_native_state(state: Dictionary) -> void:
	get_node("Text").preview_font = null
	get_node("Text").apply_native_state(state)
	var modal: bool = state.get("active", false) and state.get("kind", 0) == 1
	get_node("Dim").visible = modal
	get_node("Pause").visible = modal
	native_state_changed.emit(state.duplicate(true))
