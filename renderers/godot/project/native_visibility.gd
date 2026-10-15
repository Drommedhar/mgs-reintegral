extends RefCounted

const GROUP = "mgs_native_visibility"
var nodes: Dictionary = {}

func watch(node: Node) -> void:
	if nodes.has(node): return
	nodes[node] = true
	node.child_entered_tree.connect(watch)
	node.child_exiting_tree.connect(unwatch)
	if node is VisualInstance3D:
		node.visibility_changed.connect(update_instance.bind(node))
		update_instance(node)
	for child in node.get_children(): watch(child)

func unwatch(node: Node) -> void:
	if not nodes.has(node): return
	node.child_entered_tree.disconnect(watch)
	node.child_exiting_tree.disconnect(unwatch)
	if node is VisualInstance3D:
		node.visibility_changed.disconnect(update_instance.bind(node))
		RenderingServer.instance_set_visible(node.get_instance(), authored_visible(node))
	nodes.erase(node)
	for child in node.get_children(): unwatch(child)

func synchronize() -> void:
	for node in nodes:
		if node is VisualInstance3D: update_instance(node)

func update_instance(node: VisualInstance3D) -> void:
	var enabled := authored_visible(node)
	var ancestor: Node = node
	while enabled and ancestor != null:
		if ancestor.is_in_group(GROUP): enabled = ancestor.native_visible
		ancestor = ancestor.get_parent()
	RenderingServer.instance_set_visible(node.get_instance(), enabled)

static func authored_visible(node: VisualInstance3D) -> bool:
	return node.is_visible_in_tree() and (not node is Light3D or not node.editor_only or Engine.is_editor_hint())
