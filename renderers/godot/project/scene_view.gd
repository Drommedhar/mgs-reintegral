extends Node3D

const ReferenceMaterials = preload("res://reference_materials.gd")
const ModelContract = preload("res://model_contract.gd")
const ModelEdits = preload("res://model_edits.gd")
const ModRegistry = preload("res://mod_registry.gd")
const VisualModAPI = preload("res://visual_mod_api.gd")
const VisualRemovals = preload("res://visual_removals.gd")
const MapCoordinates = preload("res://map_coordinates.gd")
const MapLights = preload("res://map_lights.gd")
const WorldEffects = preload("res://world_effects.gd")
const EventLights = preload("res://event_lights.gd")
var effects := WorldEffects.new()
var event_lights := EventLights.new()
var mod_api := VisualModAPI.new()
var removals := VisualRemovals.new()
var materials := ReferenceMaterials.new()
var mods := ModRegistry.new()
var stage_override: Node3D
var original_lights: Node3D
var map_definitions: Dictionary = {}
var camera := Camera3D.new()
var metadata_camera := Camera3D.new()
var catalog: Dictionary
var asset_root: String
var templates: Dictionary = {}
var instances: Dictionary = {}
var prepared_instances: Dictionary = {}
var scene_stage := ""
var current_instances := 0
var projection_distance := 320.0
var horizontal_scale := 1.0
var visible_mesh_parts := 0

static func configure_shadows(viewport: Viewport, source: Viewport) -> void:
	viewport.positional_shadow_atlas_size = source.positional_shadow_atlas_size
	viewport.positional_shadow_atlas_16_bits = source.positional_shadow_atlas_16_bits
	for quadrant in 4:
		viewport.set_positional_shadow_atlas_quadrant_subdiv(quadrant, source.get_positional_shadow_atlas_quadrant_subdiv(quadrant))

func initialize() -> String:
	asset_root = OS.get_environment("MGS_GODOT_ASSETS")
	if asset_root.is_empty():
		return "Scene rendering requires a prepared asset catalog"
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(asset_root.path_join("catalog.json")))
	if not parsed is Dictionary or parsed.get("schema") != 1:
		return "Invalid prepared MGS asset catalog"
	catalog = parsed.assets
	map_definitions = parsed.get("maps", {})
	var mod_setting := OS.get_environment("MGS_GODOT_MODS")
	var mod_paths = [] if mod_setting.is_empty() else JSON.parse_string(mod_setting)
	if not mod_paths is Array:
		return "MGS_GODOT_MODS must be a JSON array"
	var mod_error := mods.configure(catalog, mod_paths)
	if not mod_error.is_empty():
		return mod_error
	var material_error := materials.initialize(catalog, mods, asset_root)
	if not material_error.is_empty(): return material_error
	for identity in mods.replacements:
		if catalog[identity].kind == "texture" and materials.texture_for(identity, false) == null:
			return "Cannot decode replacement texture: " + identity
	camera.near = 0.01
	camera.far = 250.0
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.cull_mask &= ~ReferenceMaterials.METADATA_LAYER
	metadata_camera.near = camera.near
	metadata_camera.far = camera.far
	metadata_camera.keep_aspect = camera.keep_aspect
	metadata_camera.cull_mask = ReferenceMaterials.METADATA_LAYER
	metadata_camera.environment = Environment.new()
	metadata_camera.environment.background_mode = Environment.BG_CLEAR_COLOR
	add_child(camera)
	add_child(effects)
	event_lights.name = "EventLights"
	add_child(event_lights)
	camera.current = true
	mod_api.name = "VisualMods"
	add_child(mod_api)
	var extension_error := mod_api.start(self, mods.extensions)
	if not extension_error.is_empty(): return extension_error
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
		var error := "Cannot load replacement" if replacement == null else ""
		if replacement != null and replacement.has_meta("mgs_model_reference"):
			var source: String = replacement.get_meta("mgs_model_reference")
			var edits = replacement.get_meta("mgs_part_edits", {})
			replacement.free()
			replacement = node.duplicate() as Node3D
			if source != identity and (not catalog.has(source) or catalog[source].get("sha256", "").is_empty() or catalog[source].sha256 != catalog[identity].get("sha256")):
				error = "Model reference does not match the original asset"
			elif not edits is Dictionary: error = "Model part edits must be a dictionary"
			else: error = ModelEdits.apply(replacement, edits)
		if error.is_empty(): error = ModelContract.validate(node, replacement)
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
	if prepared_instances.has(identity):
		var entry: Dictionary = prepared_instances[identity]
		prepared_instances.erase(identity)
		return entry
	return create_model(identity)

func create_model(identity: String) -> Dictionary:
	if identity == "mgs/generated/lit_mdl":
		var node := Node3D.new()
		node.name = "lit_mdl_compatibility"
		node.set_meta("mgs_asset_id", identity)
		node.set_meta("renderer_layer", "compatibility")
		add_child(node)
		return {"node": node, "bones": {}, "meshes": [], "metadata_meshes": [], "asset": identity}
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
	shade_image.fill(Color(0, 0, 0, 0))
	var packet_image := Image.create(256, height, false, Image.FORMAT_RGBAF)
	packet_image.fill(Color(0, 0, 0, 0))
	var entry := {"node": node, "bones": bones, "meshes": node.find_children("mesh_*", "MeshInstance3D", true, false),
		"asset": identity, "shade": ImageTexture.create_from_image(shade_image), "colors": PackedByteArray(),
		"packets": ImageTexture.create_from_image(packet_image), "packet_data": PackedByteArray(), "material_stages": {}, "surface_materials": {}, "transparent_parts": {}}
	entry.shadow_modes = entry.meshes.map(func(mesh): return mesh.cast_shadow)
	materials.add_metadata_meshes(entry)
	for mesh in entry.meshes: mesh.hide()
	for mesh in entry.metadata_meshes: mesh.hide()
	return entry

func prepare_stage_models(stage: String) -> String:
	for identity in prepared_instances.keys():
		if str(identity).get_slice("/", 4) not in [stage, "init"]:
			prepared_instances[identity].node.free()
			prepared_instances.erase(identity)
	for identity in templates:
		if str(identity).get_slice("/", 4) not in [stage, "init"]: continue
		if not materials.can_prepare_model(templates[identity], identity, stage): continue
		if not prepared_instances.has(identity): prepared_instances[identity] = create_model(identity)
		var entry: Dictionary = prepared_instances[identity]
		if entry.is_empty(): return "Cannot prepare model " + identity
		entry.node.show()
		for mesh in entry.meshes: mesh.show()
		var error := materials.apply(entry, stage)
		entry.node.hide()
		for mesh in entry.meshes: mesh.hide()
		if not error.is_empty(): return error
	return ""

func change_stage(stage: String) -> String:
	var material_error := materials.prepare_stage(stage)
	if not material_error.is_empty(): return material_error
	scene_stage = stage
	if original_lights != null:
		original_lights.free()
		original_lights = null
	if stage_override != null:
		remove_child(stage_override)
		stage_override.queue_free()
		stage_override = null
	var definition := mods.stage_definition(stage)
	if not definition.is_empty():
		var packed := load(definition.path) as PackedScene
		if packed == null: return "Cannot load stage override " + stage
		stage_override = packed.instantiate() as Node3D
		if stage_override == null: return "Stage override root must be Node3D"
		var coordinate_error := MapCoordinates.validate(stage_override)
		if not coordinate_error.is_empty():
			stage_override.free()
			stage_override = null
			return coordinate_error
		MapCoordinates.to_runtime(stage_override)
		for child in stage_override.get_children():
			if child.get_meta("mgs_editor_preview", false): child.free()
		add_child(stage_override)
		print("MGS_STAGE_OVERRIDE %s mod=%s source=%s" % [stage, definition.mod, mods.stage_source(stage)])
	var light_overrides = stage_override.get_meta("mgs_light_overrides", {}) if stage_override != null else {}
	var layout: Dictionary = map_definitions.get(stage, {})
	var light_error := MapLights.validate(layout, light_overrides)
	if not light_error.is_empty(): return light_error
	original_lights = MapLights.create(layout, light_overrides)
	original_lights.transform = MapCoordinates.ROTATION
	add_child(original_lights)
	var event_error := event_lights.configure(stage_override)
	if not event_error.is_empty(): return event_error
	var model_error := prepare_stage_models(stage)
	if not model_error.is_empty(): return model_error
	return removals.configure(stage_override, catalog, stage if mods.stage_source(stage) != stage else "")

func stage_name(payload: PackedByteArray, offset: int) -> String:
	var bytes := payload.slice(offset, offset + 8)
	var end := bytes.find(0)
	return bytes.slice(0, end if end >= 0 else 8).get_string_from_ascii()

func remove_instance(id: int, preserve_removal: bool = false) -> void:
	if not preserve_removal: removals.matches.erase(id)
	instances[id].node.hide()
	remove_child(instances[id].node)
	instances[id].node.queue_free()
	instances.erase(id)

func set_part_visibility(entry: Dictionary, index: int, flags: int) -> void:
	var mesh: MeshInstance3D = entry.meshes[index]
	var static_map: bool = entry.asset in map_definitions.get(scene_stage, {}).get("models", [])
	mesh.gi_mode = GeometryInstance3D.GI_MODE_STATIC if static_map and not flags & 4 else GeometryInstance3D.GI_MODE_DISABLED
	var mode: int = entry.shadow_modes[index]
	var casts := flags & 2 != 0 and mode != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if entry.get("alarm_glass", false) and flags & 4: casts = false
	mesh.visible = flags & 1 != 0 or casts
	mesh.cast_shadow = (mode if flags & 1 else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY) if casts else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not entry.metadata_meshes.is_empty():
		entry.metadata_meshes[index].visible = flags & 1 != 0
	if flags & 1 and entry.node.visible:
		visible_mesh_parts += 1

func render_extent(scale: int) -> Vector2i:
	return Vector2i(roundi(290.0 * scale / horizontal_scale), 224 * scale)

func update_scene(payload: PackedByteArray) -> String:
	if payload.size() < 68:
		return "Truncated scene header"
	var next_scale := payload.decode_float(64)
	if not is_finite(next_scale) or next_scale < 1.0 / 3.0 or next_scale > 1.0:
		return "Invalid scene horizontal scale"
	horizontal_scale = next_scale
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
		camera.fov = rad_to_deg(2.0 * atan(160.0 / (projection * horizontal_scale)))
	metadata_camera.transform = camera.transform
	metadata_camera.fov = camera.fov
	var count := payload.decode_u32(60)
	if count > 512: return "Scene instance count exceeds limit"
	var offset := 68
	var seen: Dictionary = {}
	visible_mesh_parts = 0
	for _index in count:
		if payload.size() - offset < 32:
			return "Truncated scene instance"
		var id := payload.decode_u32(offset)
		if id == 0 or seen.has(id): return "Invalid or duplicate scene instance ID"
		var asset := payload.decode_u32(offset + 4)
		var stage := stage_name(payload, offset + 8)
		var flags := payload.decode_u32(offset + 16)
		var parts := payload.decode_u32(offset + 20)
		var visible_parts := payload.decode_u32(offset + 24)
		var color_count := payload.decode_u32(offset + 28)
		offset += 32
		if parts == 0 or parts > 256 or visible_parts > parts or payload.size() - offset < parts * 52:
			return "Truncated scene bone palette"
		var identity := "mgs/integral-j/disc1/stage/%s/%04x.k" % [stage, asset]
		if asset & 0x80000000:
			if asset != 0x80000001:
				return "Unknown generated model kind"
			identity = "mgs/generated/lit_mdl"
			if color_count != 0: return "Generated model must not contain a lighting palette"
		elif not catalog.has(identity) or color_count != int(catalog[identity].colorCount):
			return "Scene lighting palette differs from prepared model: " + identity
		if payload.size() - offset - parts * 52 < color_count * 20:
			return "Truncated scene lighting or packet palette"
		if instances.has(id) and instances[id].asset != identity:
			print("MGS_SCENE_ASSET_CHANGE instance=%d %s -> %s" % [id, instances[id].asset, identity])
			remove_instance(id, true)
		if not instances.has(id):
			var instance := instantiate_model(identity)
			if instance.is_empty():
				return "Cannot instantiate " + identity
			instance.node.name = "actor_%08d" % id
			instance.node.set_meta("mgs_instance_id", id)
			instances[id] = instance
		var entry: Dictionary = instances[id]
		entry.alarm_glass = flags & 0x40000 != 0
		entry.alarm_active = flags & 0x20000 != 0
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
		for mesh_index in entry.meshes.size():
			var mesh: MeshInstance3D = entry.meshes[mesh_index]
			var part := str(mesh.name).trim_prefix("mesh_").to_int()
			var part_flags := payload.decode_u32(offset + part * 52 + 48) if part < parts else 0
			if part_flags & ~7: return "Unknown scene part flags"
			entry.transparent_parts[mesh_index] = bool(part_flags & 4)
			set_part_visibility(entry, mesh_index, part_flags)
		removals.apply(entry, id)
		var material_error := materials.apply(entry, scene_stage)
		if not material_error.is_empty(): return material_error
		seen[id] = true
		offset += parts * 52
		if color_count:
			var colors := payload.slice(offset, offset + color_count * 4)
			if entry.colors != colors:
				entry.colors = colors
				colors.resize(entry.shade.get_width() * entry.shade.get_height() * 4)
				entry.shade.update(Image.create_from_data(256, entry.shade.get_height(), false, Image.FORMAT_RGBA8, colors))
		offset += color_count * 4
		if color_count:
			var packets := payload.slice(offset, offset + color_count * 16)
			if entry.packet_data != packets:
				entry.packet_data = packets
				packets.resize(entry.packets.get_width() * entry.packets.get_height() * 16)
				entry.packets.update(Image.create_from_data(256, entry.packets.get_height(), false, Image.FORMAT_RGBAF, packets))
		offset += color_count * 16
	for id in instances.keys():
		if not seen.has(id):
			remove_instance(id)
	current_instances = seen.size()
	effects.transform = camera.transform
	if payload.size() - offset < 4: return "Missing world effect count"
	var effect_count := payload.decode_u32(offset)
	var light_offset := offset + 4 + effect_count * WorldEffects.QUAD_BYTES
	if effect_count > 65536 or light_offset > payload.size(): return "Invalid world effect payload"
	var effect_error := effects.update_effects(payload.slice(offset, light_offset), 0, scene_stage, materials)
	if not effect_error.is_empty(): return effect_error
	var light_error := event_lights.update_lights(payload, light_offset)
	if not light_error.is_empty(): return light_error
	mod_api.publish_snapshot()
	return ""

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
		var expected := Vector2(160 + projection_distance * horizontal_scale * view.x / -view.z,
			112 - projection_distance * view.y * (58.0 / 64.0) / -view.z)
		var actual := camera.unproject_position(position) * Vector2(320, 224) / Vector2(camera.get_viewport().size)
		maximum_error = maxf(maximum_error, expected.distance_to(actual))
		checked += 1
	return {"stage": scene_stage, "instances": current_instances, "godot_mesh_parts": visible_mesh_parts, "camera_fov": camera.fov,
		"projection_distance": projection_distance, "horizontal_scale": horizontal_scale, "checked_origins": checked, "max_projection_error_pixels": maximum_error,
		"godot_event_lights": event_lights.active_count}

func snapshot_owner(node: Node, root: Node) -> void:
	for child in node.get_children():
		if child.get_meta("mgs_runtime_metadata", false):
			child.free()
			continue
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
	mod_api.stop()
	if mod_api.get_parent() == null: mod_api.free()
	if camera.get_parent() == null: camera.free()
	if effects.get_parent() == null: effects.free()
	if event_lights.get_parent() == null: event_lights.free()
	if metadata_camera.get_parent() == null: metadata_camera.free()
	for template in templates.values():
		template.free()
	templates.clear()
