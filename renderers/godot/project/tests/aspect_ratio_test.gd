extends SceneTree

const SceneView = preload("res://scene_view.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if condition: return
	push_error(message)
	failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var viewport := SubViewport.new()
	root.add_child(viewport)
	var metadata := SubViewport.new()
	root.add_child(metadata)
	var scene := SceneView.new()
	viewport.add_child(scene)
	scene.add_child(scene.camera)
	metadata.add_child(scene.metadata_camera)
	scene.camera.keep_aspect = Camera3D.KEEP_WIDTH
	scene.metadata_camera.keep_aspect = Camera3D.KEEP_WIDTH
	scene.catalog = {"fixture": {}}
	var data := PackedByteArray()
	data.resize(76)
	for index in [8, 28, 48]: data.encode_float(index, 1.0)
	data.encode_float(56, 320.0)
	for aspect in [4.0 / 3.0, 16.0 / 9.0, 21.0 / 9.0, 4.0, 4.0 / 3.0]:
		var scale: float = (4.0 / 3.0) / aspect
		data.encode_float(64, scale)
		check(scene.update_scene(data).is_empty(), "Aspect snapshot rejected: " + str(aspect))
		viewport.size = scene.render_extent(4)
		metadata.size = viewport.size
		for point in [Vector3(1, 1, -4), Vector3(-1, -1, -4), Vector3(2.2, 0, -4)]:
			var expected := Vector2(160 + 320 * point.x * scale / -point.z, 112 - 290 * point.y / -point.z)
			var pixel := scene.camera.unproject_position(point) * Vector2(320, 224) / Vector2(viewport.size)
			check(pixel.distance_to(expected) < 0.1, "Wide view changed vertical framing or mismatched native packet projection")
			check(scene.camera.unproject_position(point).distance_to(scene.metadata_camera.unproject_position(point)) < 0.01,
				"Metadata camera no longer matches the color camera")
		var edge := scene.camera.unproject_position(Vector3(2.2, 0, -4))
		check((edge.x < viewport.size.x) == (aspect > 4.0 / 3.0), "Widescreen did not reveal extra world geometry")
	for invalid in [0.0, -1.0, 1.1, 0.2, INF, NAN]:
		data.encode_float(64, invalid)
		check(not scene.update_scene(data).is_empty(), "Invalid horizontal projection accepted")
	viewport.free()
	metadata.free()
	print("MGS_ASPECT_RATIO_TEST failures=%d" % failures)
	quit(1 if failures else 0)
