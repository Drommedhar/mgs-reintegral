@tool
extends Node

const Edits = preload("res://model_edits.gd")
const Contract = preload("res://model_contract.gd")
const OriginalResources = preload("res://addons/mgs_editor/original_resources.gd")
var overlay: Node3D
var reference: Node3D
var baseline: Dictionary = {}
var original_bones: Dictionary = {}
var owners: Array[Node] = []
var saving := false
var prepared := false
var error := ""

func initialize(root: Node3D, original: Node3D) -> String:
	overlay = root
	var previous := overlay.get_node_or_null("LocalModelReference") as Node3D
	reference = original
	OriginalResources.new().mark_model(original)
	original_bones = Contract.bones(original)
	reference.name = "LocalModelReference"
	overlay.add_child(reference)
	var meshes := Edits.parts(original)
	for name in meshes:
		var mesh: MeshInstance3D = meshes[name]
		var surfaces := []
		for index in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(index)
			if material is BaseMaterial3D:
				material = material.duplicate()
				material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
				mesh.set_surface_override_material(index, material)
			surfaces.append({"values": Edits.material_values(material)})
		baseline[name] = {"node": mesh, "mesh": mesh.mesh, "transform": mesh.transform, "surfaces": surfaces}
	error = Edits.apply(reference, overlay.get_meta("mgs_part_edits", {}))
	if error.is_empty() and previous != null and previous.get_meta("mgs_retail_derived", false):
		return adopt_preview(previous)
	register_nodes(reference)
	return error

func initialize_copy(root: Node3D, preview: Node3D, source: Node) -> String:
	overlay = root
	original_bones = source.original_bones.duplicate(true)
	baseline = source.baseline.duplicate(true)
	return adopt_preview(preview)

func adopt_preview(preview: Node3D) -> String:
	var meshes := Edits.parts(preview)
	if Contract.bones(preview) != original_bones or meshes.size() != baseline.size() or not baseline.keys().all(func(name): return meshes.has(name)):
		error = "Copied original preview has changed part slots or bone structure. Restore those before saving."
		return error
	for name in baseline:
		var before: Dictionary = baseline[name]
		var mesh: MeshInstance3D = meshes[name]
		before.node = mesh
		if same_geometry(before.mesh, mesh.mesh): before.mesh = mesh.mesh
	if is_instance_valid(reference):
		reference.get_parent().remove_child(reference)
		reference.queue_free()
	reference = preview
	owners.clear()
	for node in [preview] + preview.find_children("*", "", true, false):
		if node == preview or node.get_meta("mgs_retail_derived", false):
			node.owner = overlay
			owners.append(node)
	return ""

static func same_texture(left: Texture2D, right: Texture2D) -> bool:
	if left == right: return true
	if not left.get_meta("mgs_retail_derived", false) or not right.get_meta("mgs_retail_derived", false): return false
	var a := left.get_image()
	var b := right.get_image()
	return a != null and b != null and a.get_size() == b.get_size() and a.get_format() == b.get_format() and a.get_data() == b.get_data()

static func same_geometry(left: Mesh, right: Mesh) -> bool:
	if left == right: return true
	if left == null or right == null or left.get_surface_count() != right.get_surface_count(): return false
	if not left.get_meta("mgs_retail_derived", false) or not right.get_meta("mgs_retail_derived", false): return false
	if left is ArrayMesh and left.get_blend_shape_count() != 0: return false
	if right is ArrayMesh and right.get_blend_shape_count() != 0: return false
	for surface in left.get_surface_count():
		var a: int = left.surface_get_primitive_type(surface) if left is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES
		var b: int = right.surface_get_primitive_type(surface) if right is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES
		if a != b: return false
		if left.surface_get_arrays(surface) != right.surface_get_arrays(surface): return false
	return true

func register_nodes(node: Node) -> void:
	node.owner = overlay
	owners.append(node)
	for child in node.get_children(): register_nodes(child)

func collect_edits() -> Dictionary:
	var edits := {}
	if Contract.bones(reference) != original_bones: error = "Preserve the original bone names, parents and rest transforms."
	for name in baseline:
		var before: Dictionary = baseline[name]
		var mesh: MeshInstance3D = before.node
		if not is_instance_valid(mesh) or not overlay.is_ancestor_of(mesh):
			error = "Keep original mesh slots; use map visibility to remove originals."
			continue
		if mesh.mesh == null:
			error = "Model parts must retain a Mesh resource: " + name
			continue
		var edit := {}
		if mesh.mesh != before.mesh: edit.mesh = mesh.mesh
		if mesh.transform != before.transform: edit.transform = mesh.transform
		var surfaces := {}
		for index in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(index)
			if index >= before.surfaces.size() or not material is BaseMaterial3D:
				if material != null: surfaces[index] = material
				continue
			var changed := {}
			var values := Edits.material_values(material)
			for property in values:
				var value = values[property]
				var original = before.surfaces[index].values.get(property)
				if value == original: continue
				if value is Texture2D and original is Texture2D and same_texture(original, value): continue
				changed[property] = value
			if not changed.is_empty(): surfaces[index] = changed
		if not surfaces.is_empty(): edit.surfaces = surfaces
		if not edit.is_empty(): edits[name] = edit
	return edits

func prepare_save() -> void:
	if prepared: return
	prepared = true
	error = ""
	overlay.set_meta("mgs_part_edits", collect_edits())
	if not error.is_empty():
		overlay.set_meta("mgs_edit_error", error)
		push_error(error)
	elif overlay.has_meta("mgs_edit_error"): overlay.remove_meta("mgs_edit_error")
	for node in owners:
		if is_instance_valid(node): node.owner = null
	finish_save.call_deferred()

func finish_save() -> void:
	if not prepared: return
	for node in owners:
		if is_instance_valid(node) and overlay.is_ancestor_of(node): node.owner = overlay
	prepared = false
	saving = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE: saving = true
