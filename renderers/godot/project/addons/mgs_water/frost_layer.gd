@tool
extends Node3D

@export var targets: Array[NodePath] = []:
	set(value):
		targets = value
		if is_node_ready(): apply.call_deferred()
@export var material: ShaderMaterial = preload("frost.tres"):
	set(value):
		if is_node_ready() and material != null and material.changed.is_connected(apply): material.changed.disconnect(apply)
		material = value
		if is_node_ready():
			if material != null: material.changed.connect(apply)
			apply.call_deferred()
var applied: Array[Dictionary] = []
var preview_elapsed := 0.0

func _ready() -> void:
	if material != null: material.changed.connect(apply)
	apply.call_deferred()
	set_process(Engine.is_editor_hint())

func apply() -> void:
	restore()
	if material == null: return
	var up := global_basis.y.normalized()
	for path in targets:
		var target := get_node_or_null(path)
		if target == null:
			push_warning("Frost target is unavailable: " + str(path))
			continue
		var meshes := target.find_children("*", "MeshInstance3D", true, false)
		if target is MeshInstance3D: meshes.push_front(target)
		for mesh: MeshInstance3D in meshes:
			if mesh.mesh == null: continue
			for surface in mesh.mesh.get_surface_count():
				var original := mesh.get_active_material(surface)
				if original == null: continue
				var base := original.duplicate() as Material
				var layer := material.duplicate() as ShaderMaterial
				layer.set_shader_parameter("exposure_up", up)
				if original is BaseMaterial3D and original.normal_enabled:
					layer.set_shader_parameter("underlying_normal", original.normal_texture)
					layer.set_shader_parameter("use_underlying_normal", true)
				var last := base
				while last.next_pass != null:
					last.next_pass = last.next_pass.duplicate()
					last = last.next_pass
				last.next_pass = layer
				applied.append({"mesh":mesh, "surface":surface, "original":mesh.get_surface_override_material(surface), "applied":base, "layer":layer})
				mesh.set_surface_override_material(surface, base)

func restore() -> void:
	for entry in applied:
		if is_instance_valid(entry.mesh) and entry.mesh.get_surface_override_material(entry.surface) == entry.applied:
			entry.mesh.set_surface_override_material(entry.surface, entry.original)
	applied.clear()

func _process(delta: float) -> void:
	preview_elapsed += delta
	if preview_elapsed < 0.25 or material == null or material.shader == null: return
	preview_elapsed = 0.0
	for uniform in material.shader.get_shader_uniform_list():
		if uniform.name in ["exposure_up", "underlying_normal", "use_underlying_normal"]: continue
		var value = material.get_shader_parameter(uniform.name)
		for entry in applied:
			if entry.layer.get_shader_parameter(uniform.name) != value: entry.layer.set_shader_parameter(uniform.name, value)

func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE: restore()
	elif what == NOTIFICATION_EDITOR_POST_SAVE: apply.call_deferred()

func _exit_tree() -> void:
	if material != null and material.changed.is_connected(apply): material.changed.disconnect(apply)
	restore()
	request_ready()
