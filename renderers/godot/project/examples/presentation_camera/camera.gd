@tool
extends Camera3D

@export var enabled := true:
	set(value):
		enabled = value
		refresh_registration()
@export_enum("gameplay", "clip", "always") var scope := "gameplay":
	set(value):
		scope = value
		refresh_registration()
@export var clip_id := "":
	set(value):
		clip_id = value
		refresh_registration()
var api: Node

func _ready() -> void:
	if Engine.is_editor_hint(): return
	api = get_tree().get_first_node_in_group("mgs_visual_api_v1")
	refresh_registration()

func refresh_registration() -> void:
	if not is_instance_valid(api): return
	api.unregister_presentation_camera(self)
	if enabled:
		var error: String = api.register_presentation_camera(self, scope, clip_id)
		if not error.is_empty(): push_error(error)

func cut() -> void:
	if is_instance_valid(api): api.request_camera_cut(self)

func _exit_tree() -> void:
	if is_instance_valid(api): api.unregister_presentation_camera(self)
