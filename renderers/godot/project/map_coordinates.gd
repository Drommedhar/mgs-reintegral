@tool
extends RefCounted

const META = "mgs_coordinate_space"
const EDITOR = "native_y_up"
const RENDERER = "renderer"
# The prepared models and renderer use (x, -y, -z); native world Y points up.
const ROTATION = Transform3D(Basis(Vector3.RIGHT, Vector3.DOWN, Vector3.FORWARD), Vector3.ZERO)

static func validate(root: Node3D) -> String:
	var space = root.get_meta(META, RENDERER)
	return "" if space in [EDITOR, RENDERER] else "Unsupported map coordinate space: " + str(space)

static func mark_editor(root: Node3D) -> void:
	root.set_meta(META, EDITOR)
	root.set_meta("coordinates", "Original world (x,y,z)/1000; Y up; visual overrides do not change collision")

static func migrate_to_editor(root: Node3D) -> bool:
	if root.get_meta(META, RENDERER) == EDITOR: return false
	rotate_children(root, true)
	root.transform = ROTATION * root.transform * ROTATION
	mark_editor(root)
	return true

static func rotate_children(parent: Node, direct: bool) -> void:
	for child in parent.get_children():
		if child.get_meta("mgs_editor_preview", false): continue
		if child is Node3D and (direct or child.top_level or child.get_parent_node_3d() == null):
			child.transform = ROTATION * child.transform
		rotate_children(child, false)

static func to_runtime(root: Node3D) -> void:
	if root.get_meta(META, RENDERER) == EDITOR:
		root.transform = ROTATION * root.transform
		rotate_children(root, false)

static func reference_transform(root: Node3D) -> Transform3D:
	return ROTATION if root.get_meta(META, RENDERER) == EDITOR else Transform3D.IDENTITY
