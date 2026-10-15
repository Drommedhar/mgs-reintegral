extends Node3D

const ReferenceMaterials = preload("res://reference_materials.gd")
const ModelComposition = preload("res://model_composition.gd")
const ModRegistry = preload("res://mod_registry.gd")
const VisualModAPI = preload("res://visual_mod_api.gd")
const VisualRemovals = preload("res://visual_removals.gd")
const MapCoordinates = preload("res://map_coordinates.gd")
const MapLights = preload("res://map_lights.gd")
const MapEnvironment = preload("res://map_environment.gd")
const MapComposition = preload("res://map_composition.gd")
const WorldEffects = preload("res://world_effects.gd")
const EventLights = preload("res://event_lights.gd")
const ContentCatalog = preload("res://content_catalog.gd")
const NativeDeformation = preload("res://native_deformation.gd")
var content := ContentCatalog.new()
var current_disc := 1
var disc_identity := false
var object_appearance := false
var effects := WorldEffects.new()
var event_lights := EventLights.new()
var mod_api := VisualModAPI.new()
var removals := VisualRemovals.new()
var materials := ReferenceMaterials.new()
var thermal_sources := preload("res://thermal_sources.gd").new()
var mods := ModRegistry.new()
var stage_override: Node3D
var original_lights: Node3D
var default_environment: WorldEnvironment
var map_definitions: Dictionary = {}
var camera := Camera3D.new()
var cinematic_camera := preload("res://cinematic_camera.gd").new()
var cinematic_context := {}
var metadata_camera := Camera3D.new()
var catalog: Dictionary
var model_sources: RefCounted
var asset_root: String
var templates: Dictionary = {}
var instances: Dictionary = {}
var prepared_instances: Dictionary = {}
var scene_stage := ""
var current_instances := 0
var projection_distance := 320.0
var horizontal_scale := 1.0
var visible_mesh_parts := 0
var world_ready := false
var native_ordering := false

static func configure_rendering(viewport: Viewport, source: Viewport) -> void:
	configure_shadows(viewport, source)
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
	viewport.scaling_3d_scale = 1.0
	viewport.fsr_sharpness = source.fsr_sharpness
	viewport.texture_mipmap_bias = source.texture_mipmap_bias
	viewport.use_taa = false
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.use_debanding = source.use_debanding

static func configure_shadows(viewport: Viewport, source: Viewport) -> void:
	viewport.positional_shadow_atlas_size = source.positional_shadow_atlas_size
	viewport.positional_shadow_atlas_16_bits = source.positional_shadow_atlas_16_bits
	for quadrant in 4:
		viewport.set_positional_shadow_atlas_quadrant_subdiv(quadrant, source.get_positional_shadow_atlas_quadrant_subdiv(quadrant))

static func configure_metadata(viewport: Viewport) -> void:
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = 1.0
	viewport.use_taa = false
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.use_debanding = false

func initialize(content_ready: bool = false) -> String:
	asset_root = OS.get_environment("MGS_GODOT_ASSETS")
	if asset_root.is_empty():
		return "Scene rendering requires a prepared asset catalog"
	if not content_ready:
		var content_error := content.load_root(asset_root)
		if not content_error.is_empty(): return content_error
	asset_root = content.root
	catalog = content.assets
	current_disc = 1 if content.catalogs.has(1) else 2
	map_definitions = content.for_disc(current_disc).get("maps", {})
	materials.current_disc = current_disc
	print("Prepared assets verified: %d; older unverified assets: %d; discs: %s" % [content.verified_assets, content.unverified_assets, content.catalogs.keys()])
	if content.unverified_assets > 0: push_warning("Prepared catalog has no revision metadata for some assets; re-run asset preparation to verify them")
	var mod_setting := OS.get_environment("MGS_GODOT_MODS")
	var mod_paths = [] if mod_setting.is_empty() else JSON.parse_string(mod_setting)
	if not mod_paths is Array:
		return "MGS_GODOT_MODS must be a JSON array"
	var profile := preload("res://mod_profile.gd").new()
	var profile_path := OS.get_environment("MGS_GODOT_PROFILE")
	if not profile_path.is_empty():
		var profile_error := profile.read(profile_path)
		if not profile_error.is_empty(): return profile_error
		mod_paths = profile.paths()
	var mod_error := mods.configure(catalog, mod_paths, profile.priorities())
	if not mod_error.is_empty():
		return mod_error
	for diagnostic in mods.diagnostics(): print("MGS_MOD_CONFLICT " + diagnostic)
	var material_error := materials.initialize(catalog, mods, asset_root)
	if not material_error.is_empty(): return material_error
	for identity in mods.replacements:
		if catalog[identity].kind == "texture" and materials.texture_for(identity, false) == null:
			return "Cannot decode replacement texture: " + identity
	camera.near = 0.01
	camera.far = 250.0
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.cull_mask &= ~(ReferenceMaterials.METADATA_LAYER | thermal_sources.LAYER)
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
	for identity in mods.replacements:
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
	var composition := ModelComposition.new()
	var node := composition.load_model(asset_root, catalog, identity, mods, Callable(), true)
	if node == null:
		push_error(composition.error)
		return null
	if mods.replacements.has(identity):
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

func stage_models(stage: String) -> Array[String]:
	for identity in prepared_instances.keys():
		if str(identity).get_slice("/", 4) not in [stage, "init"] or str(identity).get_slice("/", 2) != "disc%d" % current_disc:
			prepared_instances[identity].node.free()
			prepared_instances.erase(identity)
	var identities: Array[String] = []
	for identity in catalog:
		if catalog[identity].kind == "model" and str(identity).get_slice("/", 4) in [stage, "init"] and str(identity).get_slice("/", 2) == "disc%d" % current_disc:
			identities.append(identity)
	return identities

func prepare_model(identity: String, stage: String) -> String:
	var template := load_template(identity)
	if template == null: return "Cannot load prepared model " + identity
	if not materials.can_prepare_model(template, identity, stage): return ""
	if not prepared_instances.has(identity): prepared_instances[identity] = create_model(identity)
	var entry: Dictionary = prepared_instances[identity]
	if entry.is_empty(): return "Cannot prepare model " + identity
	entry.node.show()
	for mesh in entry.meshes: mesh.show()
	var error := materials.apply(entry, stage)
	entry.node.hide()
	for mesh in entry.meshes: mesh.hide()
	return error

func prepare_stage_models(stage: String) -> String:
	for identity in stage_models(stage):
		var error := prepare_model(identity, stage)
		if not error.is_empty(): return error
	return ""

func prepare_stage_responsive(stage: String) -> String:
	var started := Time.get_ticks_usec()
	var error := configure_stage(stage)
	if not error.is_empty(): return error
	var assembled := Time.get_ticks_usec()
	var yielded := assembled
	for identity in stage_models(stage):
		error = prepare_model(identity, stage)
		if not error.is_empty(): return error
		if Time.get_ticks_usec() - yielded >= 16000:
			await get_tree().process_frame
			yielded = Time.get_ticks_usec()
	print("MGS_SCENE_LOAD stage=%s assembly_ms=%.3f models_ms=%.3f" % [stage,
		(assembled - started) / 1000.0, (Time.get_ticks_usec() - assembled) / 1000.0])
	return ""

func select_disc(disc: int) -> String:
	if not content.catalogs.has(disc): return "Disc %d needs its prepared content cache; run tools/prepare-godot-content.ps1 -Disc %d" % [disc, disc]
	if disc != current_disc:
		current_disc = disc
		materials.current_disc = disc
		map_definitions = content.for_disc(disc).get("maps", {})
		scene_stage = ""
	return ""

func change_stage(stage: String) -> String:
	var error := configure_stage(stage)
	return error if not error.is_empty() else prepare_stage_models(stage)

func configure_stage(stage: String) -> String:
	world_ready = false
	scene_stage = stage
	if default_environment != null:
		default_environment.free()
		default_environment = null
	if original_lights != null:
		original_lights.free()
		original_lights = null
	if stage_override != null:
		remove_child(stage_override)
		stage_override.queue_free()
		stage_override = null
	var definition := mods.stage_definition(stage, current_disc)
	if not definition.is_empty():
		var composition := MapComposition.new()
		stage_override = composition.load_stage(mods, content, stage, current_disc)
		if stage_override == null: return composition.error
		for diagnostic in composition.diagnostics: print("MGS_MAP_CONFLICT " + diagnostic)
		MapCoordinates.to_runtime(stage_override)
		add_child(stage_override)
		print("MGS_STAGE_OVERRIDE %s mod=%s source=%s" % [stage, definition.mod, mods.stage_source(stage, current_disc)])
		if stage_override.has_meta("mgs_stage_contributors"):
			print("MGS_STAGE_COMPOSITION %s contributors=%s" % [stage, stage_override.get_meta("mgs_stage_contributors")])
	if stage_override == null or MapEnvironment.find_in(stage_override) == null:
		default_environment = MapEnvironment.create()
		add_child(default_environment)
	var light_overrides = stage_override.get_meta("mgs_light_overrides", {}) if stage_override != null else {}
	var camera_edits: Dictionary = stage_override.get_meta("mgs_camera_edits", {}) if stage_override != null else {}
	var camera_error := cinematic_camera.configure(camera_edits, content)
	if not camera_error.is_empty(): return camera_error
	var layout: Dictionary = map_definitions.get(stage, {})
	var light_error := MapLights.validate(layout, light_overrides)
	if not light_error.is_empty(): return light_error
	original_lights = MapLights.create(layout, light_overrides)
	original_lights.transform = MapCoordinates.ROTATION
	add_child(original_lights)
	var event_error := event_lights.configure(stage_override)
	if not event_error.is_empty(): return event_error
	return removals.configure(stage_override, catalog, stage if ModRegistry.target_stage(mods.stage_source(stage, current_disc)) != stage else "")

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
	var gi := GeometryInstance3D.GI_MODE_STATIC if static_map and not flags & 4 else GeometryInstance3D.GI_MODE_DISABLED
	if mesh.gi_mode != gi: mesh.gi_mode = gi
	var mode: int = entry.shadow_modes[index]
	var casts := flags & 2 != 0 and mode != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var camouflaged: bool = entry.get("appearance", {}).get("kind", 0) != 0
	if camouflaged: casts = false
	if entry.get("alarm_glass", false) and flags & 4: casts = false
	mesh.visible = flags & 1 != 0 or casts
	var shadow := (mode if flags & 1 else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY) if casts else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if mesh.cast_shadow != shadow: mesh.cast_shadow = shadow
	if not entry.metadata_meshes.is_empty():
		entry.metadata_meshes[index].visible = flags & 1 != 0 and not camouflaged
	if flags & 1 and entry.node.visible:
		visible_mesh_parts += 1

func render_extent(scale: int) -> Vector2i:
	return Vector2i(roundi(290.0 * scale / horizontal_scale), 224 * scale)

static func empty_loading_snapshot(payload: PackedByteArray) -> bool:
	if payload.size() != 76: return false
	var scale := payload.decode_float(64)
	return is_finite(scale) and scale >= 1.0 / 3.0 and scale <= 1.0 and payload.decode_u32(60) == 0 and payload.decode_u32(68) == 0 and payload.decode_u32(72) == 0

func update_scene(payload: PackedByteArray, palettes = null) -> String:
	if payload.size() < 68:
		return "Truncated scene header"
	var next_scale := payload.decode_float(64)
	if not is_finite(next_scale) or next_scale < 1.0 / 3.0 or next_scale > 1.0:
		return "Invalid scene horizontal scale"
	horizontal_scale = next_scale
	if catalog.is_empty():
		return ""
	mod_api.presentation_cameras.restore(camera)
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
		var header_size := 36 if disc_identity else 32
		if object_appearance: header_size += 12
		if payload.size() - offset < header_size:
			return "Truncated scene instance"
		var id := payload.decode_u32(offset)
		if id == 0 or seen.has(id): return "Invalid or duplicate scene instance ID"
		var asset := payload.decode_u32(offset + 4)
		var stage := stage_name(payload, offset + 8)
		var flags := payload.decode_u32(offset + 16)
		var parts := payload.decode_u32(offset + 20)
		var visible_parts := payload.decode_u32(offset + 24)
		var color_count := payload.decode_u32(offset + 28)
		var disc := payload.decode_u32(offset + 32) if disc_identity else 1
		if disc not in [1, 2]: return "Invalid scene model disc"
		var appearance := {"kind": 0}
		if object_appearance:
			var start := offset + header_size - 12
			var kind := payload.decode_u32(start)
			var amount := payload.decode_float(start + 4)
			var tint := payload.decode_u32(start + 8)
			if kind > 1 or not is_finite(amount) or amount < 0.0 or amount > 1.0 or tint > 0xffffff:
				return "Invalid object appearance state"
			appearance = {"kind": kind, "amount": amount, "tint": Vector3(tint & 255, (tint >> 8) & 255, (tint >> 16) & 255) / 128.0}
		offset += header_size
		if parts == 0 or parts > 256 or visible_parts > parts or payload.size() - offset < parts * 52:
			return "Truncated scene bone palette"
		var identity := "mgs/integral-j/disc%d/stage/%s/%04x.k" % [disc, stage, asset]
		if asset & 0x80000000:
			if asset != 0x80000001:
				return "Unknown generated model kind"
			identity = "mgs/generated/lit_mdl"
			if color_count != 0: return "Generated model must not contain a lighting palette"
		elif not catalog.has(identity) or color_count != int(catalog[identity].colorCount):
			return "Scene lighting palette differs from prepared model: " + identity
		if model_sources != null and not (asset & 0x80000000):
			var source_error: String = model_sources.validate(identity, catalog[identity])
			if not source_error.is_empty(): return source_error
		var palette_bytes: int = 8 if palettes != null and color_count else color_count * 20
		if palettes != null and palettes.deformation_supported and color_count: palette_bytes += 4
		if palettes != null and palettes.live_textures_supported and color_count: palette_bytes += 4
		if payload.size() - offset - parts * 52 < palette_bytes:
			return "Truncated scene lighting or packet palette"
		var colors := PackedByteArray()
		var packets := PackedByteArray()
		var deformation := PackedByteArray()
		var deformation_revision := 0
		var live_descriptors := PackedByteArray()
		var live_revision := 0
		if color_count:
			var palette_offset := offset + parts * 52
			if palettes == null:
				colors = payload.slice(palette_offset, palette_offset + color_count * 4)
				packets = payload.slice(palette_offset + color_count * 4, palette_offset + color_count * 20)
			else:
				colors = palettes.resolve(id, 1, payload.decode_u32(palette_offset), color_count * 4)
				packets = palettes.resolve(id, 2, payload.decode_u32(palette_offset + 4), color_count * 16)
				if colors.size() != color_count * 4 or packets.size() != color_count * 16:
					return "Missing or stale scene palette resource for instance %d" % id
				if palettes.deformation_supported:
					deformation_revision = payload.decode_u32(palette_offset + 8)
					if deformation_revision:
						deformation = palettes.resolve(id, 3, deformation_revision, color_count * 12)
						if deformation.size() != color_count * 12: return "Missing or stale native deformation for instance %d" % id
				if palettes.live_textures_supported:
					live_revision = payload.decode_u32(palette_offset + 12)
					if live_revision:
						live_descriptors = palettes.resolve(id, 4, live_revision, color_count * 16)
						if live_descriptors.size() != color_count * 16: return "Missing or stale live textures for instance %d" % id
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
		if live_revision and entry.get("live_revision", 0) != live_revision:
			live_descriptors = live_descriptors.duplicate()
			live_descriptors.resize(256 * entry.packets.get_height() * 16)
			var live_image := Image.create_from_data(256, entry.packets.get_height(), false, Image.FORMAT_RGBAF, live_descriptors)
			if entry.has("live_packets"): entry.live_packets.update(live_image)
			else:
				entry.live_packets = ImageTexture.create_from_image(live_image)
				entry.material_stages.clear()
				entry.surface_materials.clear()
			entry.live_revision = live_revision
		entry.appearance = appearance
		entry.thermal = flags & 0x200 != 0
		entry.alarm_glass = flags & 0x40000 != 0
		entry.alarm_active = flags & 0x20000 != 0
		entry.node.visible = flags & 0x80 == 0
		if asset & 0x80000000 and parts > 0:
			entry.node.transform = camera.transform * matrix(payload, offset)
		var part_poses: Array[Transform3D] = []
		var bound_actor := mod_api.has_actor_binding(id)
		for part in parts:
			if payload.decode_u32(offset + part * 52 + 48) & 1: world_ready = true
			var name := "part_%03d" % part
			var transform := camera.transform * matrix(payload, offset + part * 52)
			if bound_actor: part_poses.append(transform)
			if entry.bones.has(name):
				var bone: Array = entry.bones[name]
				if absf(transform.basis.determinant()) > 0.001:
					bone[0].set_bone_global_pose(bone[1], transform)
		var actor_error := mod_api.update_actor_visuals(entry, id, part_poses)
		if not actor_error.is_empty(): return actor_error
		if deformation_revision:
			if not entry.has("deformation"): entry.deformation = NativeDeformation.new()
			var deformation_error: String = entry.deformation.apply(entry, deformation, deformation_revision, not mods.replacements.has(identity) or entry.node.get_meta("mgs_reference_model", false))
			if not deformation_error.is_empty(): return deformation_error
		for mesh_index in entry.meshes.size():
			var mesh: MeshInstance3D = entry.meshes[mesh_index]
			var part := str(mesh.name).trim_prefix("mesh_").to_int()
			var part_flags := payload.decode_u32(offset + part * 52 + 48) if part < parts else 0
			if part_flags & (0xfff8 if native_ordering else ~7): return "Unknown scene part flags"
			if native_ordering:
				var raise := part_flags >> 16
				if raise >= 32768: raise -= 65536
				if mesh.get_meta("mgs_native_raise", 0) != raise:
					mesh.set_meta("mgs_native_raise", raise)
					mesh.set_instance_shader_parameter("native_depth_bias", float(raise) * 0.000002)
					if not entry.metadata_meshes.is_empty(): entry.metadata_meshes[mesh_index].set_instance_shader_parameter("native_depth_bias", float(raise) * 0.000002)
			entry.transparent_parts[mesh_index] = bool(part_flags & 4)
			set_part_visibility(entry, mesh_index, part_flags)
		removals.apply(entry, id)
		mod_api.apply_actor_removals(entry, id)
		var material_error := materials.apply(entry, scene_stage)
		if not material_error.is_empty(): return material_error
		seen[id] = true
		offset += parts * 52
		if color_count:
			if entry.colors != colors:
				entry.colors = colors
				var image_colors := colors.duplicate()
				image_colors.resize(entry.shade.get_width() * entry.shade.get_height() * 4)
				entry.shade.update(Image.create_from_data(256, entry.shade.get_height(), false, Image.FORMAT_RGBA8, image_colors))
		if color_count:
			if entry.packet_data != packets:
				entry.packet_data = packets
				var image_packets := packets.duplicate()
				image_packets.resize(entry.packets.get_width() * entry.packets.get_height() * 16)
				entry.packets.update(Image.create_from_data(256, entry.packets.get_height(), false, Image.FORMAT_RGBAF, image_packets))
		offset += palette_bytes
	for id in instances.keys():
		if not seen.has(id):
			remove_instance(id)
	current_instances = seen.size()
	effects.transform = camera.transform
	var camera_error := cinematic_camera.apply(cinematic_context, camera, horizontal_scale)
	if not camera_error.is_empty(): return camera_error
	mod_api.camera_update_requested.emit()
	var rig_error := mod_api.presentation_cameras.apply(camera, cinematic_context, ReferenceMaterials.METADATA_LAYER | thermal_sources.LAYER)
	if not rig_error.is_empty(): return rig_error
	if payload.size() - offset < 4: return "Missing world effect count"
	var effect_count := payload.decode_u32(offset)
	var light_offset := offset + 4 + effect_count * WorldEffects.QUAD_BYTES
	if effect_count > 65536 or light_offset > payload.size(): return "Invalid world effect payload"
	var effect_error := effects.update_effects(payload.slice(offset, light_offset), 0, scene_stage, materials, camera.transform.affine_inverse() * effects.transform)
	if not effect_error.is_empty(): return effect_error
	var light_error := event_lights.update_lights(payload, light_offset)
	if not light_error.is_empty(): return light_error
	metadata_camera.transform = camera.transform
	metadata_camera.fov = camera.fov
	for property in ["projection", "keep_aspect", "near", "far", "h_offset", "v_offset"]:
		metadata_camera.set(property, camera.get(property))
	mod_api.publish_snapshot()
	return ""

func projection_diagnostics() -> Dictionary:
	var maximum_error := 0.0
	var checked := 0
	var comparable := mod_api.presentation_cameras.active_id == 0 and cinematic_camera.active_clip.is_empty()
	for instance in instances.values():
		if not comparable: break
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
		"projection_distance": projection_distance, "horizontal_scale": horizontal_scale, "checked_origins": checked,
		"native_projection_comparable": comparable, "max_projection_error_pixels": maximum_error if comparable else null,
		"presentation_camera": mod_api.presentation_cameras.active_path,
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
