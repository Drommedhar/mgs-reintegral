extends SceneTree

const DiscMap = preload("res://addons/mgs_editor/disc_map.gd")
const Authoring = preload("res://addons/mgs_editor/native_authoring.gd")
const MapAuthoring = preload("res://addons/mgs_editor/map_authoring.gd")
const Coordinates = preload("res://map_coordinates.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var directory := OS.get_environment("MGS_GODOT_ASSETS")
	var prepared = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("catalog.json")))
	if not prepared is Dictionary:
		push_error("Set MGS_GODOT_ASSETS to the locally prepared original content")
		quit(1)
		return
	var loader := DiscMap.new()
	var reference := loader.load_map(directory, prepared, "s00a")
	check(reference != null, loader.error)
	if reference == null:
		quit(1)
		return
	var overlay := Node3D.new()
	Coordinates.mark_editor(overlay)
	root.add_child(overlay)
	MapAuthoring.new().attach_reference(overlay, reference)
	var authoring := Authoring.new()
	authoring.attach_declarations(overlay, reference, overlay.get_node("_MapSession"))
	check(authoring.error.is_empty(), authoring.error)
	var seen := {}
	for binding in overlay.get_children():
		if not binding.get_meta("mgs_native_binding", false): continue
		var model: Node3D = binding.get_node("LocalModelReference")
		var identity: String = model.get_meta("mgs_asset_id")
		var parts := model.find_children("mesh_*", "MeshInstance3D", true, false)
		var visible := parts.filter(func(mesh): return mesh.visible).size()
		seen[identity.get_file()] = visible
		print("DOCK_ACTOR %s offset=%d visible_parts=%d" % [identity, binding.target.command_offset, visible])
	for identity in {"6d44.k":2, "6d45.k":1, "6d46.k":5, "6da3.k":5}:
		check(seen.get(identity) == {"6d44.k":2, "6d45.k":1, "6d46.k":5, "6da3.k":5}[identity], "Missing original actor parts: " + identity)
	await process_frame
	overlay.get_node("_MapSession").detach_for_reload()
	overlay.free()
	print("MGS_DOCKS_DECLARATIONS_TEST failures=%d" % failures)
	quit(1 if failures else 0)
