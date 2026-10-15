@tool
extends Node3D

const CollisionWorld = preload("collision_world.gd")
const Particles = preload("snow_particles.gd")
const GPU = preload("gpu_snow.gd")
const SHADER = preload("flake.gdshader")
const GROUP := "mgs_snow_volumes"

@export_group("Volume")
@export_enum("GPU weather", "Exact surfaces (CPU)") var simulation_mode := 0:
	set(value):
		simulation_mode = value
		if is_node_ready(): rebuild()
@export var volume_size := Vector3(12, 8, 12):
	set(value):
		volume_size = value
		if is_node_ready(): rebuild()
@export var enabled := true
@export var replace_original_snow := true
@export var animate_preview := false
@export var prewarm := true
@export var random_seed := 1267
@export_group("Flakes")
@export_range(0, 10000, 1) var amount := 1000:
	set(value):
		amount = clampi(value, 0, 10000)
		if is_node_ready(): reset_particles()
@export var flake_size := Vector2(0.012, 0.035)
@export var flake_color := Color(0.9, 0.95, 1.0, 0.85)
@export_range(0.0, 20.0, 0.01, "suffix:m/s") var fall_speed := 0.8
@export_range(0.0, 1.0, 0.01) var speed_variation := 0.35
@export_group("Wind")
@export var wind_velocity := Vector3(0.15, 0, 0.05)
@export_range(0.0, 10.0, 0.01) var gust_strength := 0.2
@export_range(0.0, 10.0, 0.01) var gust_speed := 0.7
@export_range(0.0, 5.0, 0.01) var flutter_strength := 0.12
@export_range(0.0, 10.0, 0.01) var flutter_speed := 1.5
@export_group("Contact")
@export_range(0.01, 10.0, 0.01, "suffix:s") var settle_time := 0.8
@export_range(0.001, 0.1, 0.001, "suffix:m") var contact_offset := 0.006
@export_group("GPU Weather Collision")
@export_flags_3d_render var weather_collision_mask := 1
@export_enum("256", "512", "1024", "2048", "4096", "8192") var weather_collision_resolution := 1
@export_group("Exact Surface Collision")
@export var collision_roots: Array[NodePath] = []:
	set(value):
		collision_roots = value
		if is_node_ready(): rebuild()
@export var collision_exclusions: Array[NodePath] = []:
	set(value):
		collision_exclusions = value
		if is_node_ready(): rebuild()
@export_tool_button("Rebuild collision") var rebuild_action: Callable = rebuild

var collision := CollisionWorld.new()
var particles := Particles.new()
var draw: MultiMeshInstance3D
var gpu: RefCounted
var material := ShaderMaterial.new()
var api: Node
var native_session := ""
var native_epoch := -1
var native_tick := -1

func _ready() -> void:
	add_to_group(GROUP)
	add_to_group("mgs_mesh_deformation_listeners")
	if draw == null: draw = MultiMeshInstance3D.new()
	material.shader = SHADER
	draw.multimesh = particles.mesh
	draw.material_override = material
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if draw.get_parent() == null: add_child(draw)
	rebuild()
	get_tree().node_added.connect(collision.queue_node)
	RenderingServer.frame_pre_draw.connect(flush_gpu)
	if not Engine.is_editor_hint():
		api = get_tree().get_first_node_in_group("mgs_visual_api_v1")
		if api != null: api.native_context_updated.connect(update_native_time)

func rebuild() -> void:
	collision.clear()
	collision.roots.clear()
	collision.exclusions.clear()
	collision.warnings.clear()
	if gpu != null:
		gpu.release()
		gpu = null
	draw.visible = simulation_mode == 1
	if simulation_mode == 0:
		particles.reset(0, random_seed)
		gpu = GPU.new()
		gpu.initialize(self, material)
		gpu.reset(self)
		update_configuration_warnings()
		return
	for path in collision_exclusions:
		var node := get_node_or_null(path)
		if node != null: collision.exclusions.append(node)
	for path in collision_roots:
		var node := get_node_or_null(path)
		if node != null: collision.roots.append(node)
	if collision_roots.is_empty():
		var scene: Node = get_tree().edited_scene_root if Engine.is_editor_hint() else get_tree().current_scene
		collision.roots.append(scene if scene != null else get_tree().root)
	for node in collision.roots: collision.collect(node)
	particles.reset(amount, random_seed)
	draw.custom_aabb = AABB(-volume_size * 0.5, volume_size).grow(flake_size.y)
	update_configuration_warnings()

func _physics_process(delta: float) -> void:
	draw.visible = active() and simulation_mode == 1
	material.set_shader_parameter("flake_color", flake_color)
	if not active() or (Engine.is_editor_hint() and not animate_preview): return
	if gpu != null:
		if api == null: advance(delta)
		return
	var warning_count := collision.warnings.size()
	collision.prepare()
	if collision.warnings.size() != warning_count: update_configuration_warnings()
	if api == null:
		collision.sync()
		advance(delta)

func active() -> bool:
	if not enabled or not is_visible_in_tree() or not volume_size.is_finite() or volume_size.x <= 0 or volume_size.y <= 0 or volume_size.z <= 0 or is_zero_approx(global_basis.determinant()): return false
	if not flake_size.is_finite() or flake_size.x <= 0 or flake_size.y < flake_size.x: return false
	var ancestor: Node = self
	while ancestor != null:
		if ancestor.is_in_group("mgs_native_visibility") and not ancestor.native_visible: return false
		ancestor = ancestor.get_parent()
	return true

func advance(delta: float) -> void:
	if not active() or not collision.pending.is_empty(): return
	if gpu != null:
		gpu.advance(delta)
		material.set_shader_parameter("snow_time", gpu.time)
		return
	particles.step(delta, self, collision)
	material.set_shader_parameter("snow_time", particles.time)

func reset_particles() -> void:
	if gpu != null: gpu.reset(self)
	else: particles.reset(amount, random_seed)

func flush_gpu() -> void:
	if gpu != null: gpu.flush(self)

func update_native_time() -> void:
	var context: Dictionary = api.get_native_context()
	if context.is_empty(): return
	if str(context.session_id) != native_session or int(context.epoch) != native_epoch:
		native_session = str(context.session_id)
		native_epoch = int(context.epoch)
		native_tick = int(context.actor_loop_tick)
		reset_particles()
		return
	if int(context.actor_loop_tick) == native_tick: return
	native_tick = int(context.actor_loop_tick)
	if int(context.pause_mask) == 0:
		if active() and gpu == null: collision.sync()
		advance(maxi(0, int(context.passage_ticks)) / (60000.0 / 1001.0))

func owns_native_snow(point: Vector3) -> bool:
	return replace_original_snow and active() and amount > 0 and collision.pending.is_empty() and AABB(-volume_size * 0.5, volume_size).has_point(to_local(point))

func mesh_vertices_updated(mesh: Mesh, surface: int, vertices: PackedVector3Array, version: int) -> void:
	collision.update_vertices(mesh, surface, vertices, version)

func _get_configuration_warnings() -> PackedStringArray:
	var result := collision.warnings.duplicate()
	if not volume_size.is_finite() or volume_size.x <= 0 or volume_size.y <= 0 or volume_size.z <= 0: result.append("Snow volume dimensions must be positive and finite.")
	if flake_size.x <= 0 or flake_size.y < flake_size.x: result.append("Flake size must be a positive minimum/maximum pair in metres.")
	for path in collision_roots + collision_exclusions:
		if not path.is_empty() and get_node_or_null(path) == null: result.append("Missing snow collision path: " + str(path))
	return result

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(flush_gpu): RenderingServer.frame_pre_draw.disconnect(flush_gpu)
	if gpu != null:
		gpu.release()
		gpu = null
	if get_tree().node_added.is_connected(collision.queue_node): get_tree().node_added.disconnect(collision.queue_node)
	if is_instance_valid(api): api.native_context_updated.disconnect(update_native_time)
	collision.clear()
	api = null
	request_ready()
