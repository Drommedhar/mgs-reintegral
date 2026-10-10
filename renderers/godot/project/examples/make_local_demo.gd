extends SceneTree

const Contract = preload("res://model_contract.gd")
const OUTPUT = "res://mods/generated-mesh-demo"

func _initialize() -> void:
	var asset_root := ProjectSettings.globalize_path("res://../../../.local/godot-content")
	var catalog = JSON.parse_string(FileAccess.get_file_as_string(asset_root.path_join("catalog.json")))
	if not catalog is Dictionary:
		push_error("Prepare your disc resources before generating this local example.")
		quit(1)
		return
	if DirAccess.dir_exists_absolute(OUTPUT):
		push_error("Example folder already exists; refusing to overwrite your edits.")
		quit(1)
		return
	var error := DirAccess.make_dir_recursive_absolute(OUTPUT)
	if error != OK:
		push_error(error_string(error))
		quit(1)
		return
	var replacements: Dictionary = {}
	for identity in catalog.assets:
		if not str(identity).ends_with("/992d.k") and not str(identity).ends_with("/7693.k"): continue
		var node := Contract.load_model(asset_root.path_join(catalog.assets[identity].path))
		if node == null:
			push_error("Cannot load " + identity)
			quit(1)
			return
		for mesh in node.find_children("*", "MeshInstance3D", true, false):
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.albedo_color = Color(0.1, 0.85, 0.9)
			mesh.material_override = material
			var replacement := ArrayMesh.new()
			for surface in mesh.mesh.get_surface_count():
				var arrays: Array = mesh.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var center := Vector3.ZERO
				for vertex in vertices: center += vertex
				center /= vertices.size()
				for index in vertices.size():
					vertices[index] = center + (vertices[index] - center) * 1.15
				arrays[Mesh.ARRAY_VERTEX] = vertices
				replacement.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.mesh = replacement
		var packed := PackedScene.new()
		error = packed.pack(node)
		var filename: String = identity.replace("/", "_") + ".tscn"
		if error == OK: error = ResourceSaver.save(packed, OUTPUT.path_join(filename))
		node.free()
		if error != OK:
			push_error(error_string(error))
			quit(1)
			return
		replacements[identity] = {"path": filename, "lighting": "unlit"}
	var manifest := {"schema": 1, "id": "example.local_mesh_swap", "priority": 20, "replacements": replacements}
	var file := FileAccess.open(OUTPUT.path_join("mod.json"), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write example manifest")
		quit(1)
		return
	file.store_string(JSON.stringify(manifest, "\t") + "\n")
	print("MGS_LOCAL_EXAMPLE %s: %d modified meshes; generated content stays ignored" % [OUTPUT, replacements.size()])
	quit(0)
