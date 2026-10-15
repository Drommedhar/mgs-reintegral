@tool
extends RefCounted

const Contract = preload("res://model_contract.gd")
const ModelSession = preload("res://addons/mgs_editor/model_session.gd")
var error := ""

func model_scene(workspace: RefCounted, identity: String) -> String:
	var existing: String = workspace.replacement_path(identity)
	if not existing.is_empty(): return existing
	var path: String = workspace.root.path_join("models/" + identity.replace("/", "_") + ".tscn")
	var root := Node3D.new()
	root.name = identity.get_file().replace(".", "_")
	root.set_meta("mgs_model_reference", identity)
	root.set_meta("mgs_part_edits", {})
	var packed := PackedScene.new()
	var result := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if result == OK: result = packed.pack(root)
	if result == OK: result = ResourceSaver.save(packed, path)
	root.free()
	if result != OK:
		error = "Cannot create model edit scene: " + error_string(result)
		return ""
	if not workspace.register_replacement(identity, path):
		error = workspace.error
		return ""
	return path

func attach_model(root: Node3D, catalog: Dictionary, asset_root: String) -> Node:
	var identity: String = root.get_meta("mgs_model_reference", "")
	if not catalog.has(identity):
		error = "Original model is missing from the prepared catalog: " + identity
		return null
	var model := Contract.load_model(asset_root.path_join(catalog[identity].path))
	if model == null:
		error = "Cannot load original model: " + identity
		return null
	var session := ModelSession.new()
	session.name = "_ModelSession"
	root.add_child(session)
	error = session.initialize(root, model)
	return session

func assign_model(workspace: RefCounted, identity: String, path: String, original_path: String) -> bool:
	var original := Contract.load_model(original_path)
	var replacement := Contract.load_model(path)
	if original == null or replacement == null: error = "Cannot load the original or replacement model"
	else: error = Contract.validate(original, replacement)
	if original != null: original.free()
	if replacement != null: replacement.free()
	if not error.is_empty(): return false
	if path.get_extension().to_lower() == "glb":
		var imported: String = workspace.root.path_join("models/" + path.get_file().get_basename() + "-" + FileAccess.get_sha256(path).left(12) + ".glb")
		if DirAccess.make_dir_recursive_absolute(imported.get_base_dir()) != OK or DirAccess.copy_absolute(path, imported) != OK:
			error = "Cannot copy GLB into the active mod"
			return false
		path = imported
	if not workspace.register_replacement(identity, path):
		error = workspace.error
		return false
	return true

func texture_ids(identity: String, catalog: Dictionary, asset_root: String) -> Array[String]:
	var result: Array[String] = []
	var model := Contract.load_model(asset_root.path_join(catalog[identity].path))
	if model == null:
		error = "Cannot load model textures: " + identity
		return result
	for mesh in model.find_children("mesh_*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var material: Material = mesh.get_active_material(surface)
			if material == null: continue
			var filename: String = material.resource_name.get_slice("_", 0) + ".p"
			var texture := identity.get_base_dir().path_join(filename)
			if not catalog.has(texture): texture = "/".join(identity.split("/").slice(0, 4)) + "/init/" + filename
			if catalog.has(texture) and texture not in result: result.append(texture)
	model.free()
	return result
