extends SceneTree

const Authoring = preload("res://addons/mgs_editor/asset_authoring.gd")
const Workspace = preload("res://addons/mgs_editor/mod_workspace.gd")
const Export = preload("res://addons/mgs_editor/mod_export.gd")
const Contract = preload("res://model_contract.gd")
const SceneView = preload("res://scene_view.gd")
const ASSET = "mgs/integral-j/disc1/stage/s00a/1234.k"
const TEXTURE = "mgs/integral-j/disc1/stage/s00a/abcd.p"
var failures := 0

func check(condition: bool, message: String) -> void:
	if condition: return
	push_error(message)
	failures += 1

func fixture() -> Node3D:
	var model := Node3D.new()
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	model.add_child(skeleton)
	skeleton.owner = model
	skeleton.add_bone("part_000")
	var mesh := MeshInstance3D.new()
	mesh.name = "mesh_000"
	mesh.mesh = QuadMesh.new()
	var material := StandardMaterial3D.new()
	material.resource_name = "abcd_original"
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	mesh.mesh.material = material
	mesh.skin = Skin.new()
	mesh.skin.add_bind(0, Transform3D.IDENTITY)
	mesh.skeleton = NodePath("../Skeleton3D")
	model.add_child(mesh)
	mesh.owner = model
	return model

func save(session: Node, path: String) -> void:
	session.prepare_save()
	var packed := PackedScene.new()
	check(packed.pack(session.overlay) == OK and ResourceSaver.save(packed, path) == OK, "Cannot save model edit scene")
	session.finish_save()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var directory := "user://asset-authoring-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	var original := fixture()
	var packed := PackedScene.new()
	packed.pack(original)
	ResourceSaver.save(packed, directory.path_join("original.tscn"))
	var workspace := Workspace.new()
	workspace.root = directory.path_join("editable")
	var authoring := Authoring.new()
	var path := authoring.model_scene(workspace, ASSET)
	check(not path.is_empty(), authoring.error)
	var overlay := Contract.load_model(path)
	root.add_child(overlay)
	var catalog := {ASSET: {"kind": "model", "path": "original.tscn", "colorCount": 4}, TEXTURE: {"kind": "texture", "path": "source.png"}}
	var session := authoring.attach_model(overlay, catalog, directory)
	check(session != null and authoring.error.is_empty(), authoring.error)
	var mesh: MeshInstance3D = overlay.get_node("LocalModelReference/mesh_000")
	check(mesh.owner == overlay, "Original character parts are absent from the Scene tree")
	var material := mesh.get_active_material(0) as StandardMaterial3D
	material.roughness = 0.27
	material.albedo_color = Color(0.7, 0.1, 0.3)
	mesh.position.x = 0.1
	save(session, path)
	var text := FileAccess.get_file_as_string(path)
	check(not "QuadMesh" in text and not "Image" in text and not "Skeleton3D" in text and not "LocalModelReference" in text, "Original model or texture leaked into saved edits")
	check(overlay.get_meta("mgs_part_edits").mesh_000.surfaces[0].size() == 2, "Material edit copied unchanged original properties")
	var runtime := SceneView.new()
	root.add_child(runtime)
	runtime.catalog = catalog
	runtime.asset_root = directory
	check(runtime.mods.configure(catalog, [workspace.root.path_join("mod.json")]).is_empty(), "Model edit manifest rejected")
	var loaded := runtime.load_template(ASSET)
	check(loaded != null and Contract.validate(original, loaded).is_empty(), "Model edits broke the original animation rig")
	check(is_equal_approx(loaded.get_node("mesh_000").get_active_material(0).roughness, 0.27), "Runtime ignored edited material")
	check(is_equal_approx(loaded.get_node("mesh_000").position.x, 0.1), "Runtime ignored edited transform")
	var zip := directory.path_join("edited.zip")
	check(Export.new().export_mod(workspace.root.path_join("mod.json"), zip).is_empty(), "Sparse character edit was not exportable")
	check(Export.new().export_mod(workspace.root.path_join("mod.json"), zip, true).is_empty(), "Explicit ZIP overwrite failed")
	var restored := Contract.load_model(path)
	root.add_child(restored)
	var reopened := authoring.attach_model(restored, catalog, directory)
	check(is_equal_approx(restored.get_node("LocalModelReference/mesh_000").get_active_material(0).roughness, 0.27), "Reopening lost material edits")
	save(reopened, path)
	check(not "QuadMesh" in FileAccess.get_file_as_string(path), "Second save embedded original geometry")
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.GREEN)
	image.save_png(directory.path_join("custom.png"))
	var texture := workspace.import_texture(TEXTURE, directory.path_join("custom.png"))
	check(not texture.is_empty() and FileAccess.file_exists(texture), "Texture assignment failed")
	check(workspace.manifest().replacements[TEXTURE].path.begins_with("textures/"), "Texture edit used another workspace")
	check(Export.new().export_mod(workspace.root.path_join("mod.json"), zip, true).is_empty(), "Texture replacement did not export")
	var archive := ZIPReader.new()
	archive.open(zip)
	var files := Array(archive.get_files()).filter(func(file): return not file.ends_with("/"))
	check(files.size() == 3, "ZIP included files besides manifest, sparse model edits and custom texture: " + str(files))
	archive.close()
	loaded.free()
	runtime.templates.clear()
	runtime.free()
	original.free()
	overlay.free()
	restored.free()
	print("MGS_ASSET_AUTHORING_TEST failures=%d" % failures)
	quit(1 if failures else 0)
