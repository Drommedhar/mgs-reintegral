extends SceneTree

var failures := 0

class SceneMock extends Node3D:
	var camera := Camera3D.new()
	var metadata_camera := Camera3D.new()
	func _init() -> void:
		add_child(camera)
		add_child(metadata_camera)

class BindingMock extends Node3D:
	var native_visible := false

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var model := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.name = "mesh_000"
	mesh.mesh = PlaneMesh.new()
	mesh.mesh.material = StandardMaterial3D.new()
	mesh.material_override = null
	mesh.set_surface_override_material(0, ShaderMaterial.new())
	model.add_child(mesh)
	var layer := load("res://addons/mgs_water/frost.tres")
	var edit_error := preload("res://model_edits.gd").apply(model, {"mesh_000":{"surfaces":{0:{"next_pass":layer}}}})
	check(edit_error.is_empty() and mesh.get_active_material(0).next_pass == layer, "Sparse edit failed after runtime reference shader conversion")
	model.free()
	var binding := BindingMock.new()
	root.add_child(binding)
	binding.add_to_group("mgs_native_visibility")
	var water: Node3D = load("res://addons/mgs_water/water_region.tscn").instantiate()
	binding.add_child(water)
	water.transform = Transform3D(Basis(Vector3.RIGHT, PI), Vector3(2,3,4))
	var point := water.to_global(Vector3(0,-1,0))
	check(water.contains_world(point), "Rotated water bounds lost local up")
	check(not water.owns_underwater_view(point), "Unavailable native binding owns water")
	binding.native_visible = true
	check(water.owns_underwater_view(point), "Available water did not own underwater view")
	water.hide()
	check(not water.owns_underwater_view(point), "Authored hidden water still owns view")
	water.show()
	water.volume_size = Vector3(-1,2,3)
	check(not water.contains_world(point) and not water.get_node("Surface").visible, "Invalid volume left stale visual or ownership")
	water.volume_size = Vector3(8,4,8)
	check(water.get_node("Surface").custom_aabb.size.y >= 0.5, "Waves escape culling bounds")
	var ocean: Node3D = load("res://addons/mgs_water/ocean.tscn").instantiate()
	root.add_child(ocean)
	check(not ocean.caustics_enabled and ocean.get_node("Surface").mesh.size.x == 1500, "Ocean preset did not configure mesh/cost")
	var api := preload("res://visual_mod_api.gd").new()
	var scene := SceneMock.new()
	root.add_child(scene)
	root.add_child(api)
	api.scene = scene
	check(api.set_view_distance(water,1800).is_empty() and scene.camera.far == 1800 and scene.metadata_camera.far == 1800, "Explicit view distance did not synchronize depth camera")
	check(api.set_view_distance(water,0).is_empty() and scene.camera.far == 250, "Removing ocean view distance did not restore native default")
	ocean.free()
	binding.free()
	api.scene = null
	api.free()
	scene.free()
	print("MGS_WATER_REGION_TEST failures=%d" % failures)
	quit(1 if failures else 0)
