@tool
extends Node3D

const Clock = preload("native_clock.gd")
const RippleState = preload("ripple_state.gd")
const Controls = preload("water_controls.gd")
const GROUP := "mgs_water_regions"

@export var volume_size := Vector3(8, 4, 8):
	set(value):
		volume_size = value
		if is_node_ready(): configure()
@export var size_plane_from_volume := true:
	set(value):
		size_plane_from_volume = value
		if is_node_ready(): configure()
@export var absorption := Vector3(0.7, 0.24, 0.15):
	set(value):
		absorption = value
		if is_node_ready(): configure()
@export var water_color := Color(0.015, 0.055, 0.045):
	set(value):
		water_color = value
		if is_node_ready(): configure()
@export var caustics_enabled := true:
	set(value):
		caustics_enabled = value
		if is_node_ready(): configure()
@export var underwater_enabled := true:
	set(value):
		underwater_enabled = value
		if is_node_ready(): configure()
@export var animate_preview := false
@export_storage var water_parameters: Dictionary = {}
@export_range(0.0, 4.0) var displacement_bounds := 0.25:
	set(value):
		displacement_bounds = value
		if is_node_ready(): configure()
var clock := Clock.new()
var ripples := RippleState.new()
var api: Node
var materials: Array[ShaderMaterial] = []
var preview_seconds := 0.0

func _get_property_list() -> Array[Dictionary]:
	return Controls.properties()

func _get(property: StringName) -> Variant:
	if not Controls.PARAMETERS.has(property): return null
	return water_parameters[property] if water_parameters.has(property) else Controls.read(self, property)

func _set(property: StringName, value: Variant) -> bool:
	if not Controls.PARAMETERS.has(property): return false
	water_parameters[property] = value
	if is_node_ready():
		Controls.apply(self, property, value)
		if property == "waves/height": configure()
	return true

func _ready() -> void:
	add_to_group(GROUP)
	for child_name in ["Surface", "Caustics", "Transmission", "Scattering"]:
		var child := get_node(child_name) as MeshInstance3D
		child.material_override = child.material_override.duplicate()
		materials.append(child.material_override)
		child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for property in water_parameters:
		if Controls.PARAMETERS.has(property): Controls.apply(self, property, water_parameters[property])
	if size_plane_from_volume and $Surface.mesh is PlaneMesh: $Surface.mesh = $Surface.mesh.duplicate()
	configure()
	set_notify_transform(true)
	if not Engine.is_editor_hint():
		api = get_tree().get_first_node_in_group("mgs_visual_api_v1")
		if api != null:
			api.native_context_updated.connect(update_native_time)
			api.snapshot_updated.connect(update_transform)
			update_native_time()
	set_process(api == null)

func configure() -> void:
	if materials.is_empty(): return
	var valid := volume_size.is_finite() and volume_size.x > 0 and volume_size.y > 0 and volume_size.z > 0
	$Surface.visible = valid
	$Caustics.visible = valid and caustics_enabled
	$Transmission.visible = valid and underwater_enabled
	$Scattering.visible = valid and underwater_enabled
	if not valid:
		update_configuration_warnings()
		return
	if size_plane_from_volume and $Surface.mesh is PlaneMesh: $Surface.mesh.size = Vector2(volume_size.x, volume_size.z)
	if $Surface.mesh is PlaneMesh:
		var plane: PlaneMesh = $Surface.mesh
		$Surface.material_override.set_shader_parameter("geometry_footprint", maxf(plane.size.x / (plane.subdivide_width + 1), plane.size.y / (plane.subdivide_depth + 1)) * 0.5)
	var wave_bounds := float(water_parameters.get("waves/height", 0.0)) * 1.6 + 0.12
	$Surface.custom_aabb = $Surface.mesh.get_aabb().grow(maxf(displacement_bounds, wave_bounds))
	var bounds := AABB(Vector3(-volume_size.x * 0.5, -volume_size.y, -volume_size.z * 0.5), volume_size)
	for child_name in ["Caustics", "Transmission", "Scattering"]: get_node(child_name).custom_aabb = bounds
	for material in materials:
		material.set_shader_parameter("volume_size", volume_size)
		if material != $Caustics.material_override:
			material.set_shader_parameter("absorption", absorption)
			material.set_shader_parameter("water_color", water_color)
	update_transform()
	update_configuration_warnings()

func update_transform() -> void:
	if not is_inside_tree() or is_zero_approx(global_basis.determinant()): return
	var inverse := global_transform.affine_inverse()
	for material in materials: material.set_shader_parameter("water_inverse", inverse)

func update_native_time() -> void:
	var previous_epoch: int = clock.epoch
	var previous_session: String = clock.session
	clock.update(api.get_native_context())
	if previous_epoch != clock.epoch or previous_session != clock.session: ripples.clear()
	set_water_time(clock.seconds)

func set_water_time(seconds: float) -> void:
	$Surface.material_override.set_shader_parameter("water_time", seconds)
	$Caustics.material_override.set_shader_parameter("water_time", seconds)
	ripples.apply($Surface.material_override, seconds)

func add_ripple(world_position: Vector3, strength: float = 0.08, width: float = 0.3, speed: float = 2.2) -> bool:
	if not accepts_surface_point(world_position) or not is_finite(strength) or not is_finite(width) or not is_finite(speed) or width <= 0 or speed <= 0: return false
	var point := to_local(world_position)
	var seconds: float = clock.seconds if api != null else preview_seconds
	ripples.add(Vector2(point.x, point.z), seconds, strength, width, speed)
	ripples.apply($Surface.material_override, seconds)
	return true

func begin_native_ripples() -> void:
	ripples.native_rings.clear()
	ripples.native_widths.clear()

func native_ripple(center: Vector3, radius: float, width: float, strength: float) -> bool:
	if not accepts_surface_point(center) or ripples.native_rings.size() >= RippleState.LIMIT: return false
	var point := to_local(center)
	var scale_xz := maxf(global_basis.x.length(), global_basis.z.length())
	ripples.native_rings.append(Vector4(point.x, point.z, radius / scale_xz, strength * 0.12))
	ripples.native_widths.append(maxf(width / scale_xz, 0.12))
	return true

func finish_native_ripples() -> void:
	ripples.finish_native(clock.seconds)
	ripples.apply($Surface.material_override, clock.seconds)

func accepts_surface_point(point: Vector3) -> bool:
	if not point.is_finite() or not is_visible_in_tree() or materials.is_empty() or is_zero_approx(global_basis.determinant()): return false
	if not volume_size.is_finite() or volume_size.x <= 0 or volume_size.y <= 0 or volume_size.z <= 0: return false
	var local := to_local(point)
	if absf(local.y) > 0.3 or absf(local.x) > volume_size.x * 0.5 or absf(local.z) > volume_size.z * 0.5: return false
	var ancestor: Node = self
	while ancestor != null:
		if ancestor.is_in_group("mgs_native_visibility") and not ancestor.native_visible: return false
		ancestor = ancestor.get_parent()
	return true

func _process(delta: float) -> void:
	if not Engine.is_editor_hint() or animate_preview:
		preview_seconds += delta
		set_water_time(preview_seconds)

func contains_world(point: Vector3) -> bool:
	if not volume_size.is_finite() or volume_size.x <= 0 or volume_size.y <= 0 or volume_size.z <= 0 or is_zero_approx(global_basis.determinant()): return false
	var local := to_local(point)
	return absf(local.x) <= volume_size.x * 0.5 and absf(local.z) <= volume_size.z * 0.5 and local.y <= 0 and local.y >= -volume_size.y

func owns_underwater_view(point: Vector3) -> bool:
	if not underwater_enabled or not is_visible_in_tree() or not contains_world(point): return false
	var ancestor: Node = self
	while ancestor != null:
		if ancestor.is_in_group("mgs_native_visibility") and not ancestor.native_visible: return false
		ancestor = ancestor.get_parent()
	return true

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not volume_size.is_finite() or volume_size.x <= 0 or volume_size.y <= 0 or volume_size.z <= 0:
		warnings.append("Water volume dimensions must be positive and finite.")
	if is_inside_tree() and is_zero_approx(global_basis.determinant()): warnings.append("Water requires a nonzero transform scale.")
	if is_inside_tree() and not $Surface.material_override.get_shader_parameter("virtual_bottom_enabled"):
		for region in get_tree().get_nodes_in_group(GROUP):
			if region == self or not region.is_visible_in_tree(): continue
			if region.get_node("Surface").material_override.get_shader_parameter("virtual_bottom_enabled"): continue
			var bounds := global_transform * AABB(Vector3(-volume_size.x * 0.5, -volume_size.y, -volume_size.z * 0.5), volume_size)
			var other: AABB = region.global_transform * AABB(Vector3(-region.volume_size.x * 0.5, -region.volume_size.y, -region.volume_size.z * 0.5), region.volume_size)
			var horizontal := Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z))
			var other_horizontal := Rect2(Vector2(other.position.x, other.position.z), Vector2(other.size.x, other.size.z))
			if horizontal.intersects(other_horizontal):
				warnings.append("Water bounds overlap or stack with %s. Screen refraction supports one visible water layer per view ray; separate these surfaces." % region.name)
	return warnings

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and is_node_ready(): update_transform()

func _exit_tree() -> void:
	if is_instance_valid(api):
		api.native_context_updated.disconnect(update_native_time)
		api.snapshot_updated.disconnect(update_transform)
	api = null
	materials.clear()
	request_ready()
