extends SceneTree

const Binding = preload("res://native_actor_binding.gd")
var failures := 0
var viewport := SubViewport.new()
var api := FixtureAPI.new()

class FixtureAPI extends Node:
	signal native_actors_updated
	signal native_context_updated
	var records := {}
	func register_actor_binding(_binding: Node) -> void: pass
	func unregister_actor_binding(_binding: Node) -> void: pass
	func resolve_native_actor(target: Dictionary) -> Dictionary:
		return {"status":"available", "actor":records[target.slot]}

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	run.call_deferred()

func binding(parent: Node, slot: int) -> Node3D:
	var body := Node3D.new()
	viewport.add_child(body)
	api.records[slot] = {"identity":{"instance":slot,"parts":1}, "body":body,
		"epoch":1,"slot":slot,"generation":1,"state":{"visible":true,"phase":0}}
	var node := Binding.new()
	node.target = {"slot":slot}
	parent.add_child(node)
	return node

func mesh(parent: Node, x: float, color: Color, lit: bool = false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.position = Vector3(x, 0, -2)
	node.mesh = QuadMesh.new()
	node.mesh.size = Vector2(0.6, 0.6)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL if lit else BaseMaterial3D.SHADING_MODE_UNSHADED
	node.material_override = material
	parent.add_child(node)
	return node

func frame() -> Image:
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func run() -> void:
	root.add_child(api)
	api.add_to_group("mgs_visual_api_v1")
	viewport.size = Vector2i(128, 128)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var camera := Camera3D.new()
	camera.environment = Environment.new()
	camera.environment.background_mode = Environment.BG_COLOR
	camera.environment.background_color = Color.BLACK
	viewport.add_child(camera)
	var outer := binding(viewport, 1)
	var inner := binding(outer, 2)
	var red := mesh(outer, -0.75, Color.RED)
	mesh(inner, 0.75, Color.GREEN)
	mesh(viewport, 0, Color.WHITE, true)
	var lamp := OmniLight3D.new()
	lamp.position.z = -1
	lamp.light_energy = 2
	outer.add_child(lamp)
	var image := await frame()
	check(image.get_pixel(32,64).r > 0.5 and image.get_pixel(96,64).g > 0.5, "Available bindings did not render")
	check(image.get_pixel(64,64).r > 0.1, "Authored light did not illuminate the unbound surface")
	lamp.editor_only = true
	api.native_actors_updated.emit()
	image = await frame()
	check(image.get_pixel(64,64).r < 0.05, "Native mask enabled an editor-only light at runtime")
	lamp.reparent(viewport)
	image = await frame()
	check(image.get_pixel(64,64).r < 0.05, "Restoring visibility enabled an editor-only light at runtime")
	lamp.editor_only = false
	lamp.reparent(outer)
	api.records[1].state.visible = false
	api.native_actors_updated.emit()
	image = await frame()
	check(image.get_pixel(32,64).r < 0.05 and image.get_pixel(96,64).g < 0.05 and image.get_pixel(64,64).r < 0.05, "Native invisibility did not mask meshes, nested bindings and lights")
	check(outer.visible and inner.visible and red.visible, "Native mask changed authored visibility properties")
	red.hide()
	red.show()
	image = await frame()
	check(image.get_pixel(32,64).r < 0.05, "Authored show escaped the native visibility mask")
	outer.hide()
	api.records[1].state.visible = true
	api.native_actors_updated.emit()
	image = await frame()
	check(image.get_pixel(32,64).r < 0.05 and not outer.visible, "Native reappearance overwrote authored hiding")
	outer.show()
	api.records[2].state.visible = false
	api.native_actors_updated.emit()
	image = await frame()
	check(image.get_pixel(32,64).r > 0.5 and image.get_pixel(96,64).g < 0.05, "Nested native visibility masks did not compose")
	api.records[1].state.visible = false
	api.native_actors_updated.emit()
	red.reparent(viewport)
	var added := mesh(outer, 0.75, Color.GREEN)
	image = await frame()
	check(image.get_pixel(32,64).r > 0.5 and image.get_pixel(96,64).g < 0.05, "Reparented or newly attached visuals retained the wrong native mask")
	added.free()
	viewport.free()
	api.free()
	print("MGS_NATIVE_VISIBILITY_TEST failures=%d" % failures)
	quit(1 if failures else 0)
