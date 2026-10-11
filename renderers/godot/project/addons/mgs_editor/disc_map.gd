@tool
extends RefCounted

const ModelContract = preload("res://model_contract.gd")
const ModelEdits = preload("res://model_edits.gd")
const Registry = preload("res://mod_registry.gd")
var error := ""
var mods := Registry.new()
var prepared_assets: Dictionary = {}

func load_map(asset_root: String, catalog: Dictionary, stage: String, manifest_path: String = "") -> Node3D:
	error = ""
	prepared_assets = catalog.assets
	mods = Registry.new()
	if not manifest_path.is_empty():
		error = mods.configure(catalog.assets, [manifest_path])
		if not error.is_empty(): return null
	var layout: Dictionary = catalog.get("maps", {}).get(stage, {})
	if layout.get("models", []).is_empty():
		error = "No prepared map definition for %s. Run tools/prepare-godot-content.ps1." % stage
		return null
	var root := Node3D.new()
	root.name = stage + "_disc_map"
	root.set_meta("mgs_editor_preview", true)
	for identity in layout.models:
		if not catalog.assets.has(identity):
			error = "Map model is missing from the catalog: " + str(identity)
			break
		var definition: Dictionary = catalog.assets[identity]
		var model := ModelContract.load_model(asset_root.path_join(definition.path))
		if model == null:
			error = "Cannot load prepared map model: " + str(identity)
			break
		if mods.replacements.has(identity):
			var replacement := ModelContract.load_model(mods.replacements[identity].path)
			if replacement == null: error = "Cannot load replacement: " + identity
			elif replacement.has_meta("mgs_model_reference"):
				error = ModelEdits.apply(model, replacement.get_meta("mgs_part_edits", {}))
				replacement.free()
			else:
				error = ModelContract.validate(model, replacement)
				model.free()
				model = replacement
			if not error.is_empty():
				model.free()
				break
		model.name = stage + "_" + str(identity).get_file().replace(".", "_")
		model.set_meta("mgs_asset_id", identity)
		model.editor_description = str(identity)
		root.add_child(model)
		for skeleton in model.find_children("*", "Skeleton3D", true, false):
			for bone in skeleton.get_bone_count(): skeleton.set_bone_global_pose(bone, Transform3D.IDENTITY)
		prepare_materials(model, definition)
		if not error.is_empty(): break
	if not error.is_empty():
		root.free()
		return null
	return root

func prepare_materials(model: Node3D, definition: Dictionary) -> void:
	var meshes := model.find_children("mesh_*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		error = "Map model contains no renderable mesh parts: " + str(model.name)
		return
	for mesh in meshes:
		mesh.visible = str(mesh.name).trim_prefix("mesh_").to_int() < int(definition.parts)
		mesh.set_meta("mgs_reference_hidden", not mesh.visible)
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(surface) as StandardMaterial3D
			if source == null or source.albedo_texture == null:
				if mods.replacements.has(str(model.get_meta("mgs_asset_id"))): continue
				error = "Map has an unresolved texture: %s/%s" % [model.name, mesh.name]
				return
			var material := source.duplicate() as StandardMaterial3D
			material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			if not mesh.get_meta("mgs_material_edits", {}).has(surface): material.roughness = 0.8
			var texture_id := str(model.get_meta("mgs_asset_id")).get_base_dir().path_join(source.resource_name.get_slice("_", 0) + ".p")
			if not prepared_assets.has(texture_id): texture_id = "mgs/integral-j/disc1/stage/init/" + source.resource_name.get_slice("_", 0) + ".p"
			if mods.replacements.has(texture_id):
				var image := Image.load_from_file(mods.replacements[texture_id].path)
				if image == null:
					error = "Cannot load replacement texture: " + texture_id
					return
				material.albedo_texture = ImageTexture.create_from_image(image)
			mesh.set_surface_override_material(surface, material)
		mesh.material_override = null
