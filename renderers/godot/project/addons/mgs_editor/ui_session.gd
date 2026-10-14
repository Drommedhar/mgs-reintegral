@tool
extends Node

var overlay: Control
var resources: RefCounted
var saving := false
var prepared := false
var error := ""

func initialize(scene: Control, originals: RefCounted) -> String:
	overlay = scene
	resources = originals
	return refresh()

func refresh() -> String:
	if overlay.has_method("bind_originals"):
		error = overlay.call("bind_originals", resources)
		if not error.is_empty(): return error
	if overlay.has_method("update_preview"):
		overlay.call("update_preview")
	elif overlay.has_method("apply_native_state"):
		var state := {"active": false, "bars": []} if overlay.get_meta("mgs_ui_slot", "") == "bars" else {"mode": 1, "active": true, "hud": true, "scan": true, "heading": 0, "layers": 7, "offsets": [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]}
		overlay.call("apply_native_state", state)
	return ""

func prepare_save() -> void:
	if prepared: return
	prepared = true
	if overlay.has_method("detach_originals"): overlay.call("detach_originals")
	finish_save.call_deferred()

func finish_save() -> void:
	if not prepared: return
	prepared = false
	saving = false
	error = refresh()
	if not error.is_empty(): push_error(error)

func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE: saving = true
