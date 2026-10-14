@tool
extends RefCounted

const ModelComposition = preload("res://model_composition.gd")
const MaterialLighting = preload("res://material_lighting.gd")
const PbrMaterials = preload("res://pbr_materials.gd")
const Registry = preload("res://mod_registry.gd")
const Cinematics = preload("res://cinematic_catalog.gd")
const OriginalResources = preload("res://addons/mgs_editor/original_resources.gd")
const Coordinates = preload("res://map_coordinates.gd")
var error := ""
var mods := Registry.new()
var pbr := PbrMaterials.new()
var prepared_assets: Dictionary = {}
var scene_stage := ""
var scene_disc := 1

func load_map(asset_root: String, catalog: Dictionary, stage: String, manifest_path: String = "", clip: String = "", context_mods: Array = [], priorities: Dictionary = {}) -> Node3D:
	error = ""
	prepared_assets = catalog.assets
	scene_stage = stage
	scene_disc = int(catalog.get("disc", 1))
	mods = Registry.new()
	var paths := context_mods.duplicate()
	if not manifest_path.is_empty() and manifest_path not in paths: paths.append(manifest_path)
	error = mods.configure(catalog.assets, paths, priorities)
	if not error.is_empty(): return null
	error = pbr.initialize(mods.materials)
	if not error.is_empty(): return null
	var layout := Cinematics.layout(catalog, stage, clip)
	if layout.get("models", []).is_empty() and layout.get("actors", []).is_empty():
		error = "No prepared map definition for %s. Run tools/prepare-godot-content.ps1." % stage
		return null
	var root := Node3D.new()
	root.name = stage + "_disc_map"
	root.set_meta("mgs_editor_preview", true)
	for identity in layout.get("models", []):
		var model := load_original(asset_root, str(identity))
		if model == null: break
		root.add_child(model)
		if not error.is_empty(): break
	if error.is_empty(): add_actor_previews(root, asset_root, layout.get("actors", []))
	if not error.is_empty():
		root.free()
		return null
	return root

func load_original(asset_root: String, identity: String) -> Node3D:
	if not prepared_assets.has(identity):
		error = "Map model is missing from the catalog: " + identity
		return null
	var composition := ModelComposition.new()
	var originals := OriginalResources.new()
	var model := composition.load_model(asset_root, prepared_assets, identity, mods, originals.mark_model)
	if model == null:
		error = composition.error
		return null
	model.name = scene_stage + "_" + identity.get_file().replace(".", "_")
	model.set_meta("mgs_asset_id", identity)
	model.editor_description = identity
	for skeleton in model.find_children("*", "Skeleton3D", true, false):
		for bone in skeleton.get_bone_count(): skeleton.set_bone_global_pose(bone, Transform3D.IDENTITY)
	prepare_materials(model, prepared_assets[identity])
	return model

func add_actor_previews(root: Node3D, asset_root: String, declarations: Array) -> void:
	for declaration in declarations:
		if declaration.status != "ready":
			var unresolved := Node3D.new()
			unresolved.name = "Unresolved_actor_%d" % declaration.target.command_offset
			unresolved.editor_description = declaration.reason
			unresolved.set_meta("mgs_declaration", declaration)
			root.add_child(unresolved)
			continue
		for role in declaration.models:
			var model := load_original(asset_root, role.asset)
			if model == null: return
			var label := "Wall" if int(declaration.target.provider) == 0xec77 else "Elevator"
			if scene_stage in ["s00a", "d00a"]:
				label = {"6d44.k":"Water", "6d45.k":"Chains", "6d46.k":"Submerged_scenery", "6da3.k":"Elevator_cart"}.get(str(role.asset).get_file(), label)
			model.name = "%s_%s_%d_%s" % [label, str(role.asset).get_file().replace(".", "_"), declaration.target.command_offset, role.role]
			model.set_meta("mgs_declaration", declaration)
			model.set_meta("mgs_model_role", role.role)
			model.editor_description = "%s · %s · procedure %s · %s" % [role.asset, declaration.activation, declaration.procedure, declaration.preview.pose]
			var pose: Dictionary = declaration.preview
			var angles := Vector3(pose.rotation[0], pose.rotation[1], pose.rotation[2]) * (TAU / 4096.0)
			var native_pose := Transform3D(Basis.from_euler(angles, EULER_ORDER_YXZ).scaled(Vector3(pose.scale[0], pose.scale[1], pose.scale[2])), Vector3(pose.position[0], pose.position[1], pose.position[2]) / 1000.0)
			model.transform = Coordinates.ROTATION * native_pose * Coordinates.ROTATION
			root.add_child(model)
			if not error.is_empty(): return

func prepare_materials(model: Node3D, definition: Dictionary) -> void:
	var meshes := model.find_children("mesh_*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		error = "Map model contains no renderable mesh parts: " + str(model.name)
		return
	for mesh in meshes:
		var part := str(mesh.name).trim_prefix("mesh_").to_int()
		var owners: Array = definition.get("partOwners", [])
		var owner: int = int(owners[part]) if part < owners.size() else part
		mesh.visible = owner < int(definition.parts)
		mesh.set_meta("mgs_reference_hidden", not mesh.visible)
		var model_id := str(model.get_meta("mgs_asset_id"))
		if mods.replacements.has(model_id) and (not model.get_meta("mgs_reference_model", false) or mesh.get_meta("mgs_custom_geometry", false)):
			MaterialLighting.apply_mesh(mesh, mods.replacements[model_id].lighting == "lit")
			continue
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if source == null: source = mesh.get_active_material(surface) as StandardMaterial3D
			if source != null and source.resource_name.get_slice("_", 0) == "0000":
				var empty := source.duplicate() as StandardMaterial3D
				empty.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				empty.albedo_color = Color(0, 0, 0, 0)
				mesh.set_surface_override_material(surface, empty)
				continue
			if source == null or source.albedo_texture == null:
				if mods.replacements.has(str(model.get_meta("mgs_asset_id"))): continue
				error = "Map has an unresolved texture: %s/%s" % [model.name, mesh.name]
				return
			var edited: Material = mesh.get_meta("mgs_material_edits", {}).get(surface)
			var material := MaterialLighting.copy(edited if edited != null else source, true)
			var texture_id := ModelComposition.texture_identity(prepared_assets, source.resource_name.get_slice("_", 0), scene_stage, scene_disc,
				model_id.get_slice("/", 4), model_id.get_slice("/", 2).trim_prefix("disc").to_int())
			var inherit_albedo: bool = edited == null or surface in mesh.get_meta("mgs_inherit_albedo", [])
			if material is BaseMaterial3D and inherit_albedo and mods.replacements.has(texture_id):
				var image := Image.load_from_file(mods.replacements[texture_id].path)
				if image == null:
					error = "Cannot load replacement texture: " + texture_id
					return
				material.albedo_texture = ImageTexture.create_from_image(image)
			if edited == null and material is StandardMaterial3D:
				if not mods.stage_definition(scene_stage, scene_disc).get("original_lighting", false) or mods.materials.has(texture_id):
					pbr.apply_standard(material, texture_id)
				else: material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			elif material is BaseMaterial3D and inherit_albedo and mods.materials.get(texture_id, {}).has("albedo"):
				material.albedo_texture = pbr.textures[mods.materials[texture_id].albedo]
			mesh.set_surface_override_material(surface, material)
		mesh.material_override = null
