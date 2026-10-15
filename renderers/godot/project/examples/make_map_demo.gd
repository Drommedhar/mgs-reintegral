extends SceneTree

const Exporter = preload("res://addons/mgs_editor/mod_export.gd")
const OUTPUT = "res://mods/map-overlay-demo"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var error := create_demo()
	if not error.is_empty(): push_error(error)
	else: print("MGS_MAP_DEMO " + OUTPUT + "/mod.json")
	quit(0 if error.is_empty() else 1)

func create_demo() -> String:
	if DirAccess.dir_exists_absolute(OUTPUT): return "Example already exists; refusing to overwrite edits"
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://../../../.local/godot-content/catalog.json"))
	if not catalog is Dictionary or catalog.get("schema") != 1: return "Prepare local disc content first"
	var result := DirAccess.make_dir_recursive_absolute(OUTPUT)
	if result != OK: return error_string(result)
	var normal := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var orm := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			normal.set_pixel(x, y, Color(0.5 + 0.15 * sin(x * PI / 4), 0.5, 1))
			orm.set_pixel(x, y, Color(1, 0.25 if (x / 4 + y / 4) % 2 == 0 else 0.7, 0.6))
	if normal.save_png(OUTPUT + "/normal.png") != OK or orm.save_png(OUTPUT + "/orm.png") != OK: return "Cannot save authored PBR textures"
	var materials: Dictionary = {}
	for identity in catalog.assets:
		if catalog.assets[identity].kind == "texture" and "/stage/s00a/" in str(identity):
			materials[identity] = {"normal": "normal.png", "orm": "orm.png"}
	var scene := Node3D.new()
	scene.name = "MapOverlayDemo"
	scene.set_meta("mgs_stage", "s00a")
	scene.set_meta("mgs_removals", [{"asset": "mgs/integral-j/disc1/stage/s00a/6da4.k", "part": 0}])
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.3, 0.4, 0.6)
	environment.environment.ambient_light_energy = 0.2
	scene.add_child(environment)
	environment.owner = scene
	var light := OmniLight3D.new()
	light.position = Vector3(-6, 3, 5)
	light.light_energy = 4
	light.omni_range = 15
	light.shadow_enabled = true
	scene.add_child(light)
	light.owner = scene
	var sphere := MeshInstance3D.new()
	sphere.name = "AuthoredPbrSphere"
	sphere.position = Vector3(-7, -1.5, 2)
	sphere.mesh = SphereMesh.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.8, 0.35, 0.1)
	material.metallic = 0.8
	material.roughness = 0.18
	sphere.material_override = material
	scene.add_child(sphere)
	sphere.owner = scene
	var packed := PackedScene.new()
	result = packed.pack(scene)
	if result == OK: result = ResourceSaver.save(packed, OUTPUT + "/stage.tscn")
	scene.free()
	if result != OK: return "Cannot save map overlay: " + error_string(result)
	var manifest := {"schema": 1, "id": "example.map_overlay", "priority": 30, "materials": materials,
		"stages": {"s00a": {"scene": "stage.tscn", "original_lighting": false}}}
	var file := FileAccess.open(OUTPUT + "/mod.json", FileAccess.WRITE)
	if file == null: return "Cannot write map demo manifest"
	file.store_string(JSON.stringify(manifest, "\t") + "\n")
	file.close()
	return Exporter.new().export_mod(OUTPUT + "/mod.json", "res://../../../build/mod-exports/map-overlay-demo.zip")
