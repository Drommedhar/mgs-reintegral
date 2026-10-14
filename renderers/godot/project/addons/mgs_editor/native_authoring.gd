@tool
extends RefCounted

const ModelContract = preload("res://model_contract.gd")
const Coordinates = preload("res://map_coordinates.gd")
const OriginalResources = preload("res://addons/mgs_editor/original_resources.gd")
const ModelSession = preload("res://addons/mgs_editor/model_session.gd")
const ASSET = "mgs/integral-j/disc1/stage/s00a/6da3.k"
const MODEL_HASH = "a2fe959f83e4a81ac0d4f33d698b7bbffdbbe9cd7b1cf7a08a4fd0ffe06fff45"
const TARGET = {"stage":"s00a", "script":0x6ea54, "command_offset":5981, "provider":0x2abc,
	"script_sha256":"40e6084b4cbf0c38660c3044238613ad2d7b24442aa2677530df49ef71ac66c8"}
var error := ""

func attach_declarations(overlay: Node3D, reference: Node3D, session: Node, workspace: String = "") -> bool:
	if not reference.get_children().any(func(node): return node.has_meta("mgs_declaration") and node.has_meta("mgs_asset_id")): return false
	var created := false
	var script: Script = preload("res://native_actor_binding.gd")
	if not workspace.is_empty():
		var directory := workspace.path_join("sdk/actor_visuals/v1")
		if DirAccess.make_dir_recursive_absolute(directory) != OK:
			error = "Cannot create the actor visual script folder"
			return false
		for file in ["native_actor_binding.gd", "native_visibility.gd"]:
			var destination := directory.path_join(file)
			if not FileAccess.file_exists(destination) and DirAccess.copy_absolute("res://" + file, destination) != OK:
				error = "Cannot copy actor visual script: " + file
				return false
		script = load(directory.path_join("native_actor_binding.gd")) as Script
		if script == null:
			error = "Cannot load the mod's actor visual script"
			return false
	for model in reference.get_children():
		if not model.has_meta("mgs_declaration") or not model.has_meta("mgs_asset_id"): continue
		var declaration: Dictionary = model.get_meta("mgs_declaration")
		var role: String = model.get_meta("mgs_model_role", "body")
		if role != "body":
			model.editor_description += " · Secondary-role binding is not available yet"
			continue
		var binding: Node3D
		for candidate in overlay.find_children("*", "Node3D", true, false):
			if not candidate.get_meta("mgs_native_binding", false): continue
			var alternatives = candidate.get("alternate_targets")
			if candidate.target == declaration.target or (alternatives is Array and declaration.target in alternatives):
				binding = candidate
				break
		if binding == null:
			binding = Node3D.new()
			binding.set_script(script)
			binding.name = model.name
			binding.target = declaration.target.duplicate(true)
			binding.transform = Coordinates.ROTATION * model.transform * Coordinates.ROTATION
			binding.set_meta("mgs_native_binding", true)
			overlay.add_child(binding, true)
			binding.owner = overlay
			created = true
		binding.editor_description = model.editor_description
		attach_declared_model(overlay, binding, model, session)
		if not error.is_empty(): return false
	return created

func attach_declared_model(overlay: Node3D, binding: Node3D, model: Node3D, session: Node) -> void:
	model.get_parent().remove_child(model)
	model.transform = Coordinates.ROTATION
	model.process_mode = Node.PROCESS_MODE_DISABLED
	var edit_session := ModelSession.new()
	session.add_child(edit_session)
	error = edit_session.initialize(binding, model)
	session.native_edits.append(edit_session)
	if not error.is_empty(): return
	register_preview(binding, edit_session, session)

func register_preview(binding: Node3D, edit_session: Node, session: Node) -> void:
	var overlay: Node3D = session.overlay
	for original in edit_session.owners:
		original.set_meta("mgs_retail_derived", true)
		original.owner = overlay
		if original not in session.originals: session.originals.append(original)
		var destination := binding
		if original is MeshInstance3D and str(original.name).begins_with("mesh_"):
			var index := str(original.name).trim_prefix("mesh_").to_int()
			var part: Node3D
			for candidate in binding.get_children():
				if candidate.get_meta("mgs_native_part", -1) == index:
					part = candidate
					break
			if part == null:
				part = Node3D.new()
				part.name = "part_%03d" % index
				part.set_meta("mgs_native_part", index)
				binding.add_child(part)
				part.owner = overlay
			destination = part
			original.visible = original.visible and not binding.hide_original_object and index not in binding.hide_original_parts
			session.native_previews.append({"binding":binding, "part":index, "node":original, "initial_hidden":original.get_meta("mgs_reference_hidden", false)})
		session.attachment_targets[original] = destination

func adopt_copied_previews(session: Node) -> void:
	for preview in session.overlay.find_children("*", "Node3D", true, false):
		if preview in session.originals or not preview.get_meta("mgs_reference_model", false) or not preview.get_meta("mgs_retail_derived", false): continue
		var binding: Node3D = preview.get_parent() as Node3D
		if binding == null or not binding.get_meta("mgs_native_binding", false): continue
		var targets: Array = [binding.target] + binding.alternate_targets
		var source: Node
		for candidate in session.native_edits:
			if not is_instance_valid(candidate.overlay): continue
			if ([candidate.overlay.target] + candidate.overlay.alternate_targets).any(func(target): return target in targets):
				source = candidate
				break
		if source == null:
			error = "Copied original preview has no matching declaration in this scene. Reopen the map before exporting."
			return
		var edit_session := ModelSession.new()
		session.add_child(edit_session)
		error = edit_session.initialize_copy(binding, preview, source)
		if not error.is_empty():
			edit_session.free()
			return
		session.native_edits.append(edit_session)
		register_preview(binding, edit_session, session)

func create_dock_binding(workspace: String, catalog: Dictionary) -> Node3D:
	if catalog.get(ASSET, {}).get("sha256") != MODEL_HASH:
		error = "Prepare the supported original dock elevator model before creating its binding"
		return null
	var path := workspace.path_join("sdk/native_actor_binding.gd")
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
		error = "Cannot create the mod SDK script folder"
		return null
	for file in ["native_actor_binding.gd", "native_visibility.gd"]:
		var destination := path.get_base_dir().path_join(file)
		if FileAccess.file_exists(destination): continue
		if DirAccess.copy_absolute("res://" + file, destination) != OK:
			error = "Cannot copy the binding script into this mod"
			return null
	var script := load(path) as Script
	if script == null:
		error = "Cannot load the mod's binding script"
		return null
	var binding := Node3D.new()
	binding.set_script(script)
	binding.name = "Elevator_b15b_6da3"
	binding.target = TARGET.duplicate(true)
	binding.position = Vector3(1, 0, -28.8)
	binding.set_meta("mgs_native_binding", true)
	binding.editor_description = "Native dock elevator. Add custom meshes/lights under its part nodes. Hide original meshes with their visibility icons; gameplay stays native."
	for index in 5:
		var part := Node3D.new()
		part.name = "part_%03d_6da3" % index
		part.set_meta("mgs_native_part", index)
		binding.add_child(part)
	return binding

func attach_previews(overlay: Node3D, catalog: Dictionary, asset_root: String, session: Node) -> void:
	for binding in overlay.find_children("*", "Node3D", true, false):
		if not binding.get_meta("mgs_native_binding", false): continue
		if binding.target != TARGET or catalog.get(ASSET, {}).get("sha256") != MODEL_HASH: continue
		var model := ModelContract.load_model(asset_root.path_join(catalog[ASSET].path))
		if model == null:
			error = "Cannot load the local elevator preview"
			return
		OriginalResources.new().mark_model(model)
		for part in binding.get_children():
			if not part.has_meta("mgs_native_part"): continue
			var index: int = part.get_meta("mgs_native_part")
			if session.native_previews.any(func(entry): return entry.binding == binding and entry.part == index): continue
			var mesh := model.find_child("mesh_%03d" % index, true, false) as MeshInstance3D
			if mesh == null: continue
			var previous := part.get_node_or_null("Original_mesh_%03d" % index)
			if previous != null:
				session.register_original(previous)
				session.native_previews.append({"binding":binding, "part":index, "node":previous})
				continue
			var preview := mesh.duplicate() as MeshInstance3D
			preview.skin = null
			preview.skeleton = NodePath()
			preview.name = "Original_mesh_%03d" % index
			preview.transform = Coordinates.ROTATION * mesh.transform
			preview.visible = not binding.hide_original_object and index not in binding.hide_original_parts
			preview.set_meta("mgs_editor_preview", true)
			preview.set_meta("mgs_native_preview_part", index)
			part.add_child(preview)
			session.register_original(preview)
			session.native_previews.append({"binding":binding, "part":index, "node":preview})
		model.free()
