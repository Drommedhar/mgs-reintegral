extends Node3D

const REFERENCE_SHADER = preload("res://reference.gdshader")
const ModelContract = preload("res://model_contract.gd")
const ModRegistry = preload("res://mod_registry.gd")
var two_sided_shader := Shader.new()
var mods := ModRegistry.new()
var stage_override: Node3D
var camera := Camera3D.new()
var catalog: Dictionary
var asset_root: String
var templates: Dictionary = {}
var textures: Dictionary = {}
var instances: Dictionary = {}
var scene_stage := ""
var current_instances := 0
var projection_distance := 320.0
var visible_mesh_parts := 0

func initialize() -> String:
	two_sided_shader.code = REFERENCE_SHADER.code.replace("unshaded, fog_disabled", "unshaded, fog_disabled, cull_disabled")
	asset_root = OS.get_environment("MGS_GODOT_ASSETS")
	if asset_root.is_empty():
		return "Scene rendering requires a prepared asset catalog"
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(asset_root.path_join("catalog.json")))
	if not parsed is Dictionary or parsed.get("schema") != 1:
		return "Invalid prepared MGS asset catalog"
	catalog = parsed.assets
	var mod_setting := OS.get_environment("MGS_GODOT_MODS")
	var mod_paths = [] if mod_setting.is_empty() else JSON.parse_string(mod_setting)
	if not mod_paths is Array:
		return "MGS_GODOT_MODS must be a JSON array"
	var mod_error := mods.configure(catalog, mod_paths)
	if not mod_error.is_empty():
		return mod_error
	for identity in mods.replacements:
		if catalog[identity].kind == "texture":
			var image := Image.load_from_file(mods.replacements[identity].path)
			if image == null: return "Cannot decode replacement texture: " + identity
			textures[identity] = ImageTexture.create_from_image(image)
	camera.near = 0.01
	camera.far = 250.0
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	add_child(camera)
	camera.current = true
	for identity in catalog:
		if catalog[identity].kind == "model" and load_template(identity) == null:
			return "Model preparation or replacement validation failed: " + identity
	print("MGS_SCENE_PRELOAD %d models" % templates.size())
	print("MGS_MODS " + JSON.stringify(mods.loaded))
	return ""

func matrix(payload: PackedByteArray, offset: int) -> Transform3D:
	var columns: Array[Vector3] = []
	var rows := Vector3(1, -1, -1)
	var axes := rows
	for column in 3:
		columns.append(Vector3(payload.decode_float(offset + column * 4) * rows.x,
			payload.decode_float(offset + 16 + column * 4) * rows.y,
			payload.decode_float(offset + 32 + column * 4) * rows.z) * axes[column])
	var origin := Vector3(payload.decode_float(offset + 12), payload.decode_float(offset + 28),
		payload.decode_float(offset + 44)) * rows / 1000.0
	return Transform3D(Basis(columns[0], columns[1], columns[2]), origin)

func load_template(identity: String) -> Node3D:
	if templates.has(identity):
		return templates[identity]
	if not catalog.has(identity):
		push_error("Prepared model missing: " + identity)
		return null
	var path := asset_root.path_join(catalog[identity].path)
	var node := ModelContract.load_model(path)
	if node == null:
		push_error("Prepared model contains no scene: " + identity)
		return null
	if mods.replacements.has(identity):
		var replacement := ModelContract.load_model(mods.replacements[identity].path)
		var error := "Cannot load replacement" if replacement == null else ModelContract.validate(node, replacement)
		if not error.is_empty():
			push_error(identity + ": " + error)
			node.free()
			if replacement != null: replacement.free()
			return null
		node.free()
		node = replacement
		print("MGS_MODEL_OVERRIDE %s mod=%s" % [identity, mods.replacements[identity].mod])
	templates[identity] = node
	return node

func instantiate_model(identity: String) -> Dictionary:
	if identity == "mgs/generated/lit_mdl":
		var node := Node3D.new()
		node.name = "lit_mdl_compatibility"
		node.set_meta("mgs_asset_id", identity)
		node.set_meta("renderer_layer", "compatibility")
		add_child(node)
		return {"node": node, "bones": {}, "meshes": [], "asset": identity}
	var template := load_template(identity)
	if template == null:
		return {}
	var node := template.duplicate() as Node3D
	add_child(node)
	node.set_meta("mgs_asset_id", identity)
	var bones: Dictionary = {}
	for skeleton in node.find_children("*", "Skeleton3D", true, false):
		for bone in skeleton.get_bone_count():
			bones[skeleton.get_bone_name(bone)] = [skeleton, bone]
	var height := maxi(1, ceili(float(catalog[identity].colorCount) / 256.0))
	var shade_image := Image.create(256, height, false, Image.FORMAT_RGBA8)
	shade_image.fill(Color(128.0 / 255.0, 128.0 / 255.0, 128.0 / 255.0, 1))
	var entry := {"node": node, "bones": bones, "meshes": node.find_children("mesh_*", "MeshInstance3D", true, false),
		"asset": identity, "shade": ImageTexture.create_from_image(shade_image), "colors": PackedByteArray()}
	resolve_stage_materials(entry)
	return entry

func stage_texture(legacy_id: String, definition_stage: String) -> Texture2D:
	for stage in [scene_stage, definition_stage, "init"]:
		var identity := "mgs/integral-j/disc1/stage/%s/%s.p" % [stage, legacy_id]
		if textures.has(identity):
			return textures[identity]
		if catalog.has(identity):
			var path: String = mods.replacements[identity].path if mods.replacements.has(identity) else asset_root.path_join(catalog[identity].path)
			var image := Image.load_from_file(path)
			if image == null:
				push_error("Cannot read prepared texture " + identity)
				return null
			var texture := ImageTexture.create_from_image(image)
			textures[identity] = texture
			return texture
	return null

func resolve_stage_materials(entry: Dictionary) -> void:
	var replaced := mods.replacements.has(entry.asset)
	var original_lighting := true
	if mods.stages.has(scene_stage): original_lighting = mods.stages[scene_stage].original_lighting
	for mesh in entry.meshes:
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if original == null:
				continue
			if replaced:
				var material := original.duplicate() as StandardMaterial3D
				material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL if mods.replacements[entry.asset].lighting == "lit" else BaseMaterial3D.SHADING_MODE_UNSHADED
				mesh.set_surface_override_material(surface, material)
				continue
			var legacy_id := original.resource_name.get_slice("_", 0)
			var texture := stage_texture(legacy_id, str(entry.asset).get_slice("/", 4))
			if texture == null:
				continue
			if not original_lighting:
				var material := original.duplicate() as StandardMaterial3D
				material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
				material.albedo_texture = texture
				material.albedo_color = Color.WHITE
				mesh.set_surface_override_material(surface, material)
				continue
			var material := ShaderMaterial.new()
			material.shader = two_sided_shader if original.cull_mode == BaseMaterial3D.CULL_DISABLED else REFERENCE_SHADER
			material.set_shader_parameter("albedo_texture", texture)
			material.set_shader_parameter("shade_texture", entry.shade)
			mesh.set_surface_override_material(surface, material)

func change_stage(stage: String) -> String:
	scene_stage = stage
	if stage_override != null:
		stage_override.queue_free()
		stage_override = null
	if mods.stages.has(stage):
		var packed := load(mods.stages[stage].path) as PackedScene
		if packed == null: return "Cannot load stage override " + stage
		stage_override = packed.instantiate() as Node3D
		if stage_override == null: return "Stage override root must be Node3D"
		for child in stage_override.get_children():
			if child.get_meta("mgs_editor_preview", false): child.free()
		add_child(stage_override)
		print("MGS_STAGE_OVERRIDE %s mod=%s" % [stage, mods.stages[stage].mod])
	for instance in instances.values():
		resolve_stage_materials(instance)
	return ""

func stage_name(payload: PackedByteArray, offset: int) -> String:
	var bytes := payload.slice(offset, offset + 8)
	var end := bytes.find(0)
	return bytes.slice(0, end if end >= 0 else 8).get_string_from_ascii()

func update_scene(payload: PackedByteArray) -> String:
	if payload.size() < 64:
		return "Truncated scene header"
	if catalog.is_empty():
		return ""
	var next_stage := stage_name(payload, 0)
	if next_stage != scene_stage:
		var error := change_stage(next_stage)
		if not error.is_empty(): return error
	var view := matrix(payload, 8)
	if absf(view.basis.determinant()) > 0.001:
		camera.transform = view.affine_inverse()
	var projection := payload.decode_float(56)
	if projection > 0:
		projection_distance = projection
		camera.fov = rad_to_deg(2.0 * atan(160.0 / projection))
	var count := payload.decode_u32(60)
	var offset := 64
	var seen: Dictionary = {}
	visible_mesh_parts = 0
	for _index in count:
		if payload.size() - offset < 32:
			return "Truncated scene instance"
		var id := payload.decode_u32(offset)
		var asset := payload.decode_u32(offset + 4)
		var stage := stage_name(payload, offset + 8)
		var flags := payload.decode_u32(offset + 16)
		var parts := payload.decode_u32(offset + 20)
		var visible_parts := payload.decode_u32(offset + 24)
		var color_count := payload.decode_u32(offset + 28)
		offset += 32
		if parts > 256 or visible_parts > parts or payload.size() - offset < parts * 52:
			return "Truncated scene bone palette"
		var identity := "mgs/integral-j/disc1/stage/%s/%04x.k" % [stage, asset]
		if asset & 0x80000000:
			if asset != 0x80000001:
				return "Unknown generated model kind"
			identity = "mgs/generated/lit_mdl"
		if instances.has(id) and instances[id].asset != identity:
			print("MGS_SCENE_ASSET_CHANGE instance=%d %s -> %s" % [id, instances[id].asset, identity])
			instances[id].node.queue_free()
			instances.erase(id)
		if not instances.has(id):
			var instance := instantiate_model(identity)
			if instance.is_empty():
				return "Cannot instantiate " + identity
			instance.node.name = "actor_%08d" % id
			instance.node.set_meta("mgs_instance_id", id)
			instances[id] = instance
		var entry: Dictionary = instances[id]
		entry.node.visible = flags & 0x80 == 0
		if asset & 0x80000000 and parts > 0:
			entry.node.transform = camera.transform * matrix(payload, offset)
		for part in parts:
			var name := "part_%03d" % part
			if entry.bones.has(name):
				var bone: Array = entry.bones[name]
				var transform := camera.transform * matrix(payload, offset + part * 52)
				if absf(transform.basis.determinant()) > 0.001:
					bone[0].set_bone_global_pose(bone[1], transform)
		for mesh in entry.meshes:
			var part := str(mesh.name).trim_prefix("mesh_").to_int()
			mesh.visible = part < parts and payload.decode_u32(offset + part * 52 + 48) != 0
			if mesh.visible and entry.node.visible:
				visible_mesh_parts += 1
		seen[id] = true
		offset += parts * 52
		if payload.size() - offset < color_count * 4:
			return "Truncated scene lighting palette"
		if color_count:
			if color_count != int(catalog[identity].colorCount):
				return "Scene lighting palette differs from prepared model: " + identity
			var colors := payload.slice(offset, offset + color_count * 4)
			if entry.colors != colors:
				entry.colors = colors
				colors.resize(entry.shade.get_width() * entry.shade.get_height() * 4)
				entry.shade.update(Image.create_from_data(256, entry.shade.get_height(), false, Image.FORMAT_RGBA8, colors))
		offset += color_count * 4
	for id in instances.keys():
		if not seen.has(id):
			instances[id].node.queue_free()
			instances.erase(id)
	current_instances = seen.size()
	return "" if offset == payload.size() else "Trailing scene data"

func projection_diagnostics() -> Dictionary:
	var maximum_error := 0.0
	var checked := 0
	for instance in instances.values():
		if not instance.bones.has("part_000"):
			continue
		var bone: Array = instance.bones["part_000"]
		var position: Vector3 = bone[0].get_bone_global_pose(bone[1]).origin
		var view := camera.transform.affine_inverse() * position
		if view.z >= -0.01:
			continue
		var expected := Vector2(160 + projection_distance * view.x / -view.z,
			112 - projection_distance * view.y * (58.0 / 64.0) / -view.z)
		var actual := camera.unproject_position(position) * Vector2(320.0 / 580.0, 0.5)
		maximum_error = maxf(maximum_error, expected.distance_to(actual))
		checked += 1
	return {"stage": scene_stage, "instances": current_instances, "godot_mesh_parts": visible_mesh_parts, "camera_fov": camera.fov,
		"projection_distance": projection_distance, "checked_origins": checked, "max_projection_error_pixels": maximum_error}

func snapshot_owner(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		snapshot_owner(child, root)

func export_snapshot() -> String:
	if instances.is_empty(): return "No live stage to capture"
	var root := Node3D.new()
	root.name = scene_stage + "_preview"
	for entry in instances.values():
		var copy := entry.node.duplicate() as Node3D
		root.add_child(copy)
	var view := camera.duplicate() as Camera3D
	view.compositor = null
	view.name = "ReferenceCamera"
	root.add_child(view)
	snapshot_owner(root, root)
	var folder := "res://.generated/previews"
	var error := DirAccess.make_dir_recursive_absolute(folder)
	var packed := PackedScene.new()
	if error == OK: error = packed.pack(root)
	var path := folder.path_join(scene_stage + ".tscn")
	if error == OK: error = ResourceSaver.save(packed, path)
	root.free()
	if error != OK: return "Cannot export stage preview: " + error_string(error)
	print("MGS_STAGE_PREVIEW " + path)
	return ""

func _exit_tree() -> void:
	if camera.get_parent() == null: camera.free()
	for template in templates.values():
		template.free()
	templates.clear()
