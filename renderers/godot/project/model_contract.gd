@tool
extends RefCounted

static func bones(node: Node3D) -> Dictionary:
	var result: Dictionary = {}
	for skeleton in node.find_children("*", "Skeleton3D", true, false):
		for index in skeleton.get_bone_count():
			var name: String = skeleton.get_bone_name(index)
			var parent: int = skeleton.get_bone_parent(index)
			result[name] = {"parent": skeleton.get_bone_name(parent) if parent >= 0 else "",
				"rest": skeleton.get_bone_rest(index)}
	return result

static func validate(reference: Node3D, replacement: Node3D) -> String:
	var expected := bones(reference)
	var actual := bones(replacement)
	if expected.size() != actual.size():
		return "Replacement must retain the original bone count"
	for name in expected:
		if not actual.has(name) or actual[name].parent != expected[name].parent:
			return "Replacement changed bone name/parent: " + name
		if not actual[name].rest.is_equal_approx(expected[name].rest):
			return "Replacement changed bone rest transform: " + name
	var allowed: Dictionary = {}
	for mesh in reference.find_children("*", "MeshInstance3D", true, false):
		allowed[str(mesh.name)] = mesh
	var seen: Dictionary = {}
	for mesh in replacement.find_children("*", "MeshInstance3D", true, false):
		var name := str(mesh.name)
		if not allowed.has(name) or seen.has(name):
			return "Replacement mesh must use a unique original part name: " + name
		if mesh.skin == null or mesh.get_node_or_null(mesh.skeleton) == null:
			return "Replacement part must retain its skeleton binding: " + name
		var skin: Skin = allowed[name].skin
		if skin == null or skin.get_bind_count() != mesh.skin.get_bind_count():
			return "Replacement changed skin bind count: " + name
		for bind in skin.get_bind_count():
			if skin.get_bind_bone(bind) != mesh.skin.get_bind_bone(bind) or skin.get_bind_name(bind) != mesh.skin.get_bind_name(bind):
				return "Replacement changed skin bone mapping: " + name
			if not skin.get_bind_pose(bind).is_equal_approx(mesh.skin.get_bind_pose(bind)):
				return "Replacement changed skin bind pose: " + name
		seen[name] = true
	return "" if seen.size() == allowed.size() else "Replacement removed an original mesh/attachment slot"

static func load_model(path: String) -> Node3D:
	if path.get_extension().to_lower() == "tscn":
		var scene := load(path) as PackedScene
		if scene == null: return null
		var node := scene.instantiate()
		if node is Node3D: return node
		node.free()
		return null
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path, state) != OK:
		return null
	return document.generate_scene(state) as Node3D
