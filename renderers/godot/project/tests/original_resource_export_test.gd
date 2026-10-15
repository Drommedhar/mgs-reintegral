extends SceneTree

const Marker = preload("res://addons/mgs_editor/original_resources.gd")
const DiscMap = preload("res://addons/mgs_editor/disc_map.gd")
const Export = preload("res://addons/mgs_editor/mod_export.gd")
const ModelSession = preload("res://addons/mgs_editor/model_session.gd")
const ASSET = "mgs/integral-j/disc1/stage/s00a/1234.k"
var directory := "user://original-resources-%d" % Time.get_ticks_usec()
var workspace := directory.path_join("mod")
var catalog_path := directory.path_join("catalog.json")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func fixture(color: Color = Color(0.34, 0.56, 0.78)) -> Node3D:
	var model := Node3D.new()
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	model.add_child(skeleton)
	skeleton.owner = model
	skeleton.add_bone("part_000")
	var mesh := MeshInstance3D.new()
	mesh.name = "mesh_000"
	mesh.mesh = BoxMesh.new()
	mesh.skin = Skin.new()
	mesh.skin.add_bind(0, Transform3D.IDENTITY)
	mesh.skeleton = NodePath("../Skeleton3D")
	var material := StandardMaterial3D.new()
	material.resource_name = "1234_original"
	var pixels := Image.create(3, 2, false, Image.FORMAT_RGBA8)
	pixels.fill(color)
	material.albedo_texture = ImageTexture.create_from_image(pixels)
	material.normal_texture = ImageTexture.create_from_image(pixels)
	mesh.mesh.material = material
	model.add_child(mesh)
	mesh.owner = model
	return model

func save_scene(node: Node, path: String) -> void:
	var packed := PackedScene.new()
	check(packed.pack(node) == OK and ResourceSaver.save(packed, path) == OK, "Cannot save fixture scene: " + path)

func manifest(path: String, replacements: Dictionary) -> void:
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify({"schema":1,"id":"test.original-resources","replacements":replacements}))

func rejected_resource(resource: Resource, name: String, tagged: bool = true) -> void:
	for deep in [false, true]:
		var copy := resource.duplicate(deep)
		if tagged: check(copy.get_meta("mgs_retail_derived", false), "Duplication lost provenance: " + name)
		for extension in ["tres", "res"]:
			var filename := "%s-%s.%s" % [name, deep, extension]
			var path := workspace.path_join(filename)
			check(ResourceSaver.save(copy, path) == OK, "Cannot serialize copied resource: " + filename)
			var restored := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
			check(restored != null, "Cannot reopen copied resource: " + filename)
			if tagged: check(restored.get_meta("mgs_retail_derived", false), "Reopen lost provenance: " + filename)
			manifest(workspace.path_join("mod.json"), {ASSET:{"path":filename}})
			var exporter := Export.new()
			exporter.catalog_paths = [catalog_path]
			var error := exporter.prepare(workspace.path_join("mod.json"))
			check("Export refuses" in error, "Copied original resource exported: " + filename + " / " + error)

func map_resources() -> void:
	var original := fixture()
	save_scene(original, directory.path_join("original.tscn"))
	original.free()
	var catalog := {"assets":{ASSET:{"kind":"model","path":"original.tscn","parts":1}},"maps":{"s00a":{"models":[ASSET]}}}
	var loader := DiscMap.new()
	var map := loader.load_map(directory, catalog, "s00a")
	check(map != null, "Cannot prepare original map: " + loader.error)
	if map == null: return
	var mesh: MeshInstance3D = map.get_child(0).get_node("mesh_000")
	rejected_resource(mesh.mesh, "mesh")
	rejected_resource(mesh.skin, "skin")
	rejected_resource(mesh.get_active_material(0).albedo_texture, "albedo")
	rejected_resource(mesh.get_active_material(0).normal_texture, "normal")
	map.free()
	var replacement := fixture(Color(0.91, 0.27, 0.13))
	save_scene(replacement, workspace.path_join("custom.tscn"))
	replacement.free()
	manifest(workspace.path_join("mod.json"), {ASSET:{"path":"custom.tscn"}})
	map = loader.load_map(directory, catalog, "s00a", workspace.path_join("mod.json"))
	check(map != null, "Cannot preview a full custom replacement: " + loader.error)
	if map == null: return
	mesh = map.get_child(0).get_node("mesh_000")
	check(not mesh.mesh.has_meta("mgs_retail_derived") and not mesh.skin.has_meta("mgs_retail_derived"), "Custom replacement mesh/skin marked as original")
	check(not mesh.get_active_material(0).albedo_texture.has_meta("mgs_retail_derived"), "Custom replacement texture marked as original")
	check(Export.new().export_mod(workspace.path_join("mod.json"), directory.path_join("custom.zip")).is_empty(), "Custom model cannot export after map preview")
	map.free()

func model_session() -> void:
	var overlay := Node3D.new()
	root.add_child(overlay)
	var session := ModelSession.new()
	overlay.add_child(session)
	var original := fixture()
	check(session.initialize(overlay, original).is_empty(), "Cannot attach original model")
	var mesh: MeshInstance3D = original.get_node("mesh_000")
	check(mesh.skin.get_meta("mgs_retail_derived", false), "Model session left original skin unmarked")
	check(mesh.get_active_material(0).normal_texture.get_meta("mgs_retail_derived", false), "Model session left original normal texture unmarked")
	var custom := SphereMesh.new()
	custom.material = StandardMaterial3D.new()
	custom.material.albedo_texture = GradientTexture2D.new()
	mesh.mesh = custom
	mesh.set_surface_override_material(0, custom.material)
	session.prepare_save()
	save_scene(overlay, workspace.path_join("edited.tscn"))
	session.finish_save()
	manifest(workspace.path_join("mod.json"), {ASSET:{"path":"edited.tscn"}})
	check(Export.new().export_mod(workspace.path_join("mod.json"), directory.path_join("edited.zip")).is_empty(), "Fresh mesh/material edit inherited original provenance")
	overlay.free()

func nested_resources() -> void:
	var image := Image.create(3, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.31, 0.57, 0.79))
	var font := FontFile.new()
	font.set_texture_image(0, Vector2i(8, 0), 0, image)
	var animation := Animation.new()
	var library := AnimationLibrary.new()
	library.add_animation("Original", animation)
	var marker := Marker.new()
	marker.mark_value({"font":font,"clips":[library]})
	rejected_resource(font, "font")
	rejected_resource(font.get_texture_image(0, Vector2i(8, 0), 0), "font-image", false)
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(font.get_texture_image(0, Vector2i(8, 0), 0))
	rejected_resource(material, "untagged-material", false)
	var detached_font := font.duplicate(true) as FontFile
	detached_font.remove_meta("mgs_retail_derived")
	rejected_resource(detached_font, "untagged-font", false)
	rejected_resource(library, "library")
	rejected_resource(animation, "animation")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(workspace)
	var image := Image.create(3, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.31, 0.57, 0.79))
	image.save_png(directory.path_join("original.png"))
	var digest := FileAccess.get_sha256(directory.path_join("original.png"))
	FileAccess.open(catalog_path, FileAccess.WRITE).store_string(JSON.stringify({"schema":1,"assets":{"original/font":{"sha256":digest,"preparedFiles":{"original.png":digest}}}}))
	map_resources()
	model_session()
	nested_resources()
	print("MGS_ORIGINAL_RESOURCE_EXPORT_TEST failures=%d" % failures)
	quit(1 if failures else 0)
