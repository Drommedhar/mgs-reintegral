extends SceneTree

const MapAuthoring = preload("res://addons/mgs_editor/map_authoring.gd")
const ModExport = preload("res://addons/mgs_editor/mod_export.gd")
const Removals = preload("res://visual_removals.gd")
const ASSET = "mgs/integral-j/disc1/stage/s00a/0001.k"
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func check_dependencies(directory: String) -> void:
	var source := directory.path_join("source")
	DirAccess.make_dir_recursive_absolute(source.path_join("assets"))
	DirAccess.make_dir_recursive_absolute(source.path_join("scripts"))
	var material_path := source.path_join("assets/material.tres")
	var script_path := source.path_join("scripts/custom.gd")
	ResourceSaver.save(StandardMaterial3D.new(), material_path)
	var script := "extends Node3D\n@export var probe_path: NodePath\nconst MATERIAL = preload( '%s')\nfunc load_material() -> Resource:\n\treturn MATERIAL\n" % material_path
	FileAccess.open(script_path, FileAccess.WRITE).store_string(script)
	var scene := '[gd_scene load_steps=4 format=3]\n[ext_resource type="Material" path="%s" id="1"]\n[ext_resource type="Script" path="%s" id="2"]\n[sub_resource type="BoxMesh" id="Box"]\n[node name="Overlay" type="Node3D"]\nscript = ExtResource("2")\nprobe_path = NodePath("AuthoredObject")\n[node name="AuthoredObject" type="MeshInstance3D" parent="."]\nmesh = SubResource("Box")\nmaterial_override = ExtResource("1")\n' % [material_path, script_path]
	FileAccess.open(source.path_join("stage.tscn"), FileAccess.WRITE).store_string(scene)
	var manifest := {"schema": 1, "id": "test.dependencies", "stages": {"s00a": {"scene": "stage.tscn"}}}
	FileAccess.open(source.path_join("mod.json"), FileAccess.WRITE).store_string(JSON.stringify(manifest))
	var archive := directory.path_join("dependencies.zip")
	check(ModExport.new().export_mod(source.path_join("mod.json"), archive).is_empty(), "Authored dependency export failed")
	var reader := ZIPReader.new()
	if reader.open(archive) != OK:
		check(false, "Dependency ZIP cannot be opened")
		return
	var exported := Array(reader.get_files()).filter(func(path): return not str(path).ends_with("/"))
	check(exported.size() == 4, "Authored dependencies missing or unrelated files exported")
	var installed := directory.path_join("installed")
	for name in exported:
		var target := installed.path_join(name)
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		var bytes := reader.read_file(name)
		check(not source in bytes.get_string_from_utf8(), "Export retained source resource paths")
		FileAccess.open(target, FileAccess.WRITE).store_buffer(bytes)
	reader.close()
	var packed := load(installed.path_join("stage.tscn")) as PackedScene
	check(packed != null, "Relocated scene cannot be loaded")
	if packed == null: return
	var restored := packed.instantiate()
	var material := restored.call("load_material") as Material
	check(material != null and material.resource_path.begins_with(installed), "Relocated script did not load its packaged material")
	check(restored.get_node("AuthoredObject").material_override == material, "Scene and script resolved different materials")
	restored.free()
	FileAccess.open(script_path, FileAccess.WRITE).store_string(script.replace("return MATERIAL", 'return load( "%s")' % material_path))
	check("use preload()" in ModExport.new().export_mod(source.path_join("mod.json"), directory.path_join("runtime-load.zip")), "Nonportable runtime load() did not produce an actionable export error")

func run() -> void:
	var directory := "user://map-export-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	var overlay := Node3D.new()
	overlay.set_meta("mgs_stage", "s00a")
	root.add_child(overlay)
	var original := Node3D.new()
	var actor := Node3D.new()
	actor.name = "Original"
	actor.position = Vector3(1, 2, 3)
	actor.set_meta("mgs_asset_id", ASSET)
	original.add_child(actor)
	actor.owner = original
	var mesh := MeshInstance3D.new()
	mesh.name = "mesh_000"
	mesh.mesh = BoxMesh.new()
	actor.add_child(mesh)
	mesh.owner = original
	var packed := PackedScene.new()
	check(packed.pack(original) == OK, "Cannot pack synthetic original")
	original.free()
	var authoring := MapAuthoring.new()
	authoring.attach_preview(overlay, packed)
	var selected := overlay.get_node("LocalMapReference/Original/mesh_000")
	var rule := authoring.removal_for(selected, overlay, false)
	check(rule.asset == ASSET and rule.anchor == Vector3(1, 2, 3), "Removal did not store a stable reference and position")
	authoring.set_removals(overlay, [rule])
	check(not selected.get_parent().visible, "Editor did not hide selected original")
	var light := OmniLight3D.new()
	light.name = "AuthoredLight"
	light.shadow_enabled = true
	overlay.add_child(light)
	light.owner = overlay
	var saved := PackedScene.new()
	overlay.propagate_notification(Node.NOTIFICATION_EDITOR_PRE_SAVE)
	overlay.get_node("_MapSession").prepare_save()
	check(saved.pack(overlay) == OK, "Cannot pack mod overlay")
	check(ResourceSaver.save(saved, directory.path_join("stage.tscn")) == OK, "Cannot save mod overlay")
	overlay.propagate_notification(Node.NOTIFICATION_EDITOR_POST_SAVE)
	overlay.get_node("_MapSession").finish_save()
	var restored := saved.instantiate() as Node3D
	check(restored.get_node_or_null("LocalMapReference") == null, "Local retail preview was serialized")
	check(restored.get_node("AuthoredLight").shadow_enabled, "Authored shadow light was lost")
	var removals := Removals.new()
	check(removals.configure(restored, {ASSET: {"kind": "model"}}).is_empty(), "Valid removal rule rejected")
	var entry := {"asset": ASSET, "node": selected.get_parent(), "meshes": [selected], "metadata_meshes": []}
	entry.node.show()
	removals.apply(entry, 1)
	check(not entry.node.visible, "Original remained visible at runtime")
	entry.node.position += Vector3(10, 0, 0)
	entry.node.show()
	removals.apply(entry, 1)
	check(not entry.node.visible, "Moving actor escaped a matched removal")
	entry.node.show()
	removals.apply(entry, 2)
	check(entry.node.visible, "Position selector removed a different actor")
	var manifest := {"schema": 1, "id": "test.overlay", "stages": {"s00a": {"scene": "stage.tscn", "original_lighting": false}}}
	var manifest_path := directory.path_join("mod.json")
	FileAccess.open(manifest_path, FileAccess.WRITE).store_string(JSON.stringify(manifest))
	var archive := directory.path_join("overlay.zip")
	check(ModExport.new().export_mod(manifest_path, archive).is_empty(), "Clean overlay export failed")
	var reader := ZIPReader.new()
	check(reader.open(archive) == OK, "Exported ZIP cannot be opened")
	var exported := Array(reader.get_files())
	exported.sort()
	check(exported == ["mod.json", "stage.tscn"], "Export included files other than mod instructions/authored scene")
	check(not "mgs_asset_id" in reader.read_file("stage.tscn").get_string_from_utf8(), "Retail reference leaked into ZIP")
	reader.close()
	ResourceSaver.save(packed, directory.path_join("retail.tscn"))
	manifest.stages.s00a.scene = "retail.tscn"
	FileAccess.open(manifest_path, FileAccess.WRITE).store_string(JSON.stringify(manifest))
	check(not ModExport.new().export_mod(manifest_path, directory.path_join("bad.zip")).is_empty(), "Exporter accepted embedded original geometry")
	check(not FileAccess.file_exists(directory.path_join("bad.zip")), "Rejected export created a partial archive")
	manifest.stages.s00a.scene = "../external.tscn"
	FileAccess.open(manifest_path, FileAccess.WRITE).store_string(JSON.stringify(manifest))
	check(not ModExport.new().export_mod(manifest_path, directory.path_join("outside.zip")).is_empty(), "Exporter accepted external dependencies")
	check_dependencies(directory)
	restored.free()
	overlay.free()
	print("MGS_MAP_OVERLAY_TEST failures=%d" % failures)
	quit(1 if failures else 0)
