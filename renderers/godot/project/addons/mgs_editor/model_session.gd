@tool
extends Node

const Edits = preload("res://model_edits.gd")
const Contract = preload("res://model_contract.gd")
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
	reference = original
	original_bones = Contract.bones(original)
	reference.name = "LocalModelReference"
	overlay.add_child(reference)
	var meshes := Edits.parts(original)
	for name in meshes:
		var mesh: MeshInstance3D = meshes[name]
		var surfaces := []
		mesh.mesh.set_meta("mgs_retail_derived", true)
		for index in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(index)
			if material is BaseMaterial3D:
				material = material.duplicate()
				material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
				mesh.set_surface_override_material(index, material)
				if material.albedo_texture != null: material.albedo_texture.set_meta("mgs_retail_derived", true)
			surfaces.append({"values": Edits.material_values(material)})
		baseline[name] = {"node": mesh, "mesh": mesh.mesh, "transform": mesh.transform, "surfaces": surfaces}
	error = Edits.apply(reference, overlay.get_meta("mgs_part_edits", {}))
	register_nodes(reference)
	return error

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
				if values[property] != before.surfaces[index].values.get(property): changed[property] = values[property]
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
