@tool
extends Control

signal native_state_changed(state: Dictionary)

@export_range(0, 1024) var preview_health := 640:
	set(value):
		preview_health = value
		if Engine.is_editor_hint(): update_preview.call_deferred()
@export_range(0, 1024) var preview_oxygen := 768:
	set(value):
		preview_oxygen = value
		if Engine.is_editor_hint(): update_preview.call_deferred()
var _resources: RefCounted
var _templates: Dictionary = {}
var _instances: Dictionary = {}
var _template_visibility: Dictionary = {}
var _native_active := false

func bind_originals(resources: RefCounted) -> String:
	_resources = resources
	_templates.clear()
	for node in get_children():
		if node is Control and node.get("kind") != null and not node.has_meta("mgs_runtime_bar"):
			if _templates.has(node.kind): return "Status bars require one template per kind"
			_templates[node.kind] = node
			if not _native_active: _template_visibility[node] = node.visible
			var error: String = node.bind_originals(resources)
			if not error.is_empty(): return error
	return "" if _templates.size() == 3 else "Status bars require Life, Oxygen and Other templates"

func detach_originals() -> void:
	for node in _instances.values():
		if is_instance_valid(node): node.free()
	_instances.clear()
	for node in _templates.values():
		if _native_active: node.visible = _template_visibility[node]
		node.detach_originals()
	_native_active = false

func update_preview() -> void:
	if _resources == null: return
	detach_originals()
	var error := bind_originals(_resources)
	if not error.is_empty():
		push_error(error)
		return
	for kind in _templates:
		var node: Control = _templates[kind]
		node.apply_native_state({"position": Vector2(16, 40) if kind == 0 else node.native_origin, "rest": 896 if kind == 1 else 768,
			"value": preview_health if kind == 1 else preview_oxygen if kind == 2 else 768,
			"maximum": 1024, "height": 4 if kind == 2 else 5, "kind": kind, "damage": 0,
			"name": "LIFE" if kind == 1 else "O2" if kind == 2 else "BOSS",
			"left": 0x9f6f10, "right": 0x7fdf1f})

func apply_native_state(state: Dictionary) -> void:
	_native_active = true
	for node in _templates.values(): node.hide()
	for node in _instances.values(): node.hide()
	var occurrences := {}
	for bar in state.get("bars", []):
		if not _template_visibility[_templates[bar.kind]]: continue
		var identity := "%d:%s" % [bar.kind, bar.name]
		var index: int = occurrences.get(identity, 0)
		occurrences[identity] = index + 1
		var key := identity + ":" + str(index)
		if not _instances.has(key):
			var template: Control = _templates[bar.kind]
			template.detach_originals()
			var node := template.duplicate() as Control
			node.set_meta("mgs_runtime_bar", true)
			add_child(node)
			var error: String = node.bind_originals(_resources)
			if not error.is_empty(): push_error(error)
			_instances[key] = node
		var instance: Control = _instances[key]
		instance.show()
		instance.apply_native_state(bar)
		move_child(instance, 0)
	for key in _instances.keys():
		if not _instances[key].visible:
			_instances[key].free()
			_instances.erase(key)
	native_state_changed.emit(state.duplicate(true))
