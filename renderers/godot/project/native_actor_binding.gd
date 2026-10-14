@tool
extends Node3D

const NativeVisibility = preload("native_visibility.gd")

signal availability_changed(available: bool)
signal state_changed(state: Dictionary)

@export var target: Dictionary = {}
@export var alternate_targets: Array[Dictionary] = []
@export var hide_original_parts := PackedInt32Array()
@export var hide_original_object := false
@export var attachment_offset := Transform3D.IDENTITY

var binding_status := "Editor preview"
var native_state: Dictionary = {}
var bound_instance := 0
var incarnation := Vector3i.ZERO
var api: Node
var native_visible := false
var native_visibility := NativeVisibility.new()
var part_offsets: Dictionary = {}

func apply_part_poses(poses: Array[Transform3D]) -> void:
	if poses.is_empty() or bound_instance == 0: return
	var conversion := Transform3D(Basis(Vector3.RIGHT, Vector3.DOWN, Vector3.FORWARD), Vector3.ZERO)
	var body := poses[0] * conversion
	if is_zero_approx(body.basis.determinant()): return
	global_transform = body * attachment_offset
	var offset := global_transform * body.affine_inverse()
	for part in get_children():
		if not part is Node3D or not part.has_meta("mgs_native_part"): continue
		var index: int = part.get_meta("mgs_native_part")
		if index < 0 or index >= poses.size(): continue
		if not part_offsets.has(part): part_offsets[part] = part.transform
		part.global_transform = offset * poses[index] * conversion * part_offsets[part]

func _ready() -> void:
	if Engine.is_editor_hint(): return
	clear_binding(bound_instance)
	add_to_group(NativeVisibility.GROUP)
	native_visibility.watch(self)
	api = get_tree().get_first_node_in_group("mgs_visual_api_v1")
	if api == null:
		binding_status = "Native game is not connected"
		return
	api.register_actor_binding(self)
	api.native_actors_updated.connect(refresh)
	api.native_context_updated.connect(refresh)
	refresh()

func resolve_targets() -> Dictionary:
	var available := {}
	var result := {}
	for declaration in [target] + alternate_targets:
		result = api.resolve_native_actor(declaration)
		if result.status == "available":
			if not available.is_empty(): return {"status":"ambiguous", "message":"Multiple authored declaration alternatives are active"}
			available = result
		elif result.status != "inactive": return result
	return available if not available.is_empty() else result

func refresh() -> void:
	var result := resolve_targets()
	var previous := bound_instance
	bound_instance = 0
	binding_status = str(result.get("message", result.status))
	if result.status == "available":
		var actor: Dictionary = result.actor
		for part in hide_original_parts:
			if part < 0 or part >= actor.identity.parts:
				binding_status = "Original part index is outside this actor"
				clear_binding(previous)
				return
		var parent := get_parent_node_3d()
		if parent != null and is_zero_approx(parent.global_basis.determinant()):
			binding_status = "Binding parent has zero scale"
			clear_binding(previous)
			return
		bound_instance = actor.identity.instance
		global_transform = actor.body.global_transform * attachment_offset
		native_visible = actor.state.visible
		var next := Vector3i(actor.epoch, actor.slot, actor.generation)
		if next != incarnation or native_state != actor.state:
			incarnation = next
			native_state = actor.state.duplicate(true)
			state_changed.emit(native_state.duplicate(true))
	else:
		clear_binding(previous)
		return
	native_visibility.synchronize()
	if (previous != 0) != (bound_instance != 0): availability_changed.emit(bound_instance != 0)

func clear_binding(previous: int) -> void:
	bound_instance = 0
	incarnation = Vector3i.ZERO
	native_state.clear()
	native_visible = false
	native_visibility.synchronize()
	if previous != 0: availability_changed.emit(false)

func _exit_tree() -> void:
	if is_in_group(NativeVisibility.GROUP): remove_from_group(NativeVisibility.GROUP)
	native_visibility.unwatch(self)
	if is_instance_valid(api):
		api.native_actors_updated.disconnect(refresh)
		api.native_context_updated.disconnect(refresh)
		api.unregister_actor_binding(self)
	request_ready()
