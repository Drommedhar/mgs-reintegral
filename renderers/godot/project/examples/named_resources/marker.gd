extends MeshInstance3D

@export_enum("amber", "teal") var finish := "amber"

func _ready() -> void:
	var api := get_tree().get_first_node_in_group("mgs_visual_api_v1")
	if api == null:
		push_error("Run this example through the native test session to connect its mod resources.")
		return
	var entry: Dictionary = api.resolve_mod_resource(self, "finish/" + finish)
	if entry.status != "ready":
		push_error(entry.message)
		return
	var material := load(entry.path) as Material
	if material == null:
		push_error("The selected finish must be a Godot Material: " + entry.path)
		return
	material_override = material
	print("MGS_NAMED_RESOURCE mod=%s finish=%s path=%s" % [entry.mod, finish, entry.path])
