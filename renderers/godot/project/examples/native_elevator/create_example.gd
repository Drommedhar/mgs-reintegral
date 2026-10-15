extends SceneTree

const Authoring = preload("res://addons/mgs_editor/native_authoring.gd")
const Coordinates = preload("res://map_coordinates.gd")
const Export = preload("res://addons/mgs_editor/mod_export.gd")
const WORKSPACE = "res://mods/sdk-native-elevator"

func box(parent: Node3D, name: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	node.position = position
	parent.add_child(node)
	return node

func own(node: Node, scene: Node) -> void:
	for child in node.get_children():
		child.owner = scene
		own(child, scene)

func _initialize() -> void:
	var scene_path := WORKSPACE.path_join("s00a.tscn")
	if FileAccess.file_exists(scene_path):
		push_error("Example workspace already exists; preserve local edits by choosing another output folder.")
		quit(1)
		return
	var catalog_path := "res://../../../.local/godot-content/catalog.json"
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
	var authoring := Authoring.new()
	var binding := authoring.create_dock_binding(WORKSPACE, catalog.assets)
	if binding == null:
		push_error(authoring.error)
		quit(1)
		return
	var overlay := Node3D.new()
	overlay.name = "DockElevatorExample"
	overlay.set_meta("mgs_stage", "s00a")
	Coordinates.mark_editor(overlay)
	overlay.add_child(binding)
	binding.hide_original_object = true
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.22, 0.25, 0.28)
	metal.metallic = 0.75
	metal.roughness = 0.45
	box(binding.get_child(1), "Platform", Vector3(3, 0.4, 3), Vector3(0, -0.2, 0), metal)
	var railing := Node3D.new()
	railing.name = "Railing"
	binding.get_child(2).add_child(railing)
	for x in [-1.35, 1.35]:
		for z in [-1.35, 1.35]: box(railing, "Post", Vector3(0.08, 1, 0.08), Vector3(x, 0.5, z), metal)
		box(railing, "SideRail", Vector3(0.08, 0.08, 2.8), Vector3(x, 0.95, 0), metal)
	box(railing, "BackRail", Vector3(2.8, 0.08, 0.08), Vector3(0, 0.95, -1.35), metal)
	var lamp := OmniLight3D.new()
	lamp.name = "AttachedLamp"
	lamp.position = Vector3(0, 1.2, -1.2)
	lamp.light_color = Color(1, 0.8, 0.55)
	lamp.light_energy = 0.65
	lamp.omni_range = 5
	lamp.shadow_enabled = true
	railing.add_child(lamp)
	var indicator_material := StandardMaterial3D.new()
	indicator_material.emission_enabled = true
	indicator_material.albedo_color = Color(0.1, 0.1, 0.1)
	var indicator := box(binding, "MotionIndicator", Vector3(0.15, 0.1, 0.1), Vector3(0, 1, -1.35), indicator_material)
	var script_path := WORKSPACE.path_join("indicator.gd")
	var result := DirAccess.copy_absolute("res://examples/native_elevator/indicator.gd", script_path)
	if result == OK: indicator.set_script(load(script_path))
	own(overlay, overlay)
	var packed := PackedScene.new()
	if result == OK: result = packed.pack(overlay)
	if result == OK: result = ResourceSaver.save(packed, scene_path)
	overlay.free()
	var manifest := {"schema":1, "id":"sdk.native-elevator", "priority":100,
		"stages":{"s00a":{"scene":"s00a.tscn"}}}
	var file := FileAccess.open(WORKSPACE.path_join("mod.json"), FileAccess.WRITE)
	if file == null: result = ERR_CANT_CREATE
	else: file.store_string(JSON.stringify(manifest, "\t") + "\n")
	file = null
	var error := Export.new().export_mod(WORKSPACE.path_join("mod.json"), "res://../../../build/mod-exports/sdk-native-elevator.zip") if result == OK else error_string(result)
	if not error.is_empty(): push_error(error)
	print("MGS_ELEVATOR_EXAMPLE " + ("created" if error.is_empty() else error))
	quit(0 if error.is_empty() else 1)
