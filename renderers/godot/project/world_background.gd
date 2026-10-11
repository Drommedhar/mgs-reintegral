extends SubViewport

const LIGHT_LAYER = 1 << 18
var camera: Camera3D
var source_viewport: SubViewport

func initialize(source: SubViewport) -> void:
	source_viewport = source
	camera = Camera3D.new()
	world_3d = source.find_world_3d()
	transparent_bg = false
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	camera.cull_mask = LIGHT_LAYER
	add_child(camera)
	camera.current = true
	for light in source.find_children("*", "Light3D", true, false):
		include_light(light)
	get_tree().node_added.connect(include_light)

func include_light(node: Node) -> void:
	if node is Light3D and source_viewport.is_ancestor_of(node):
		node.layers |= LIGHT_LAYER

func render(source: Camera3D, extent: Vector2i) -> void:
	size = Vector2i(maxi(1, extent.x / 4), maxi(1, extent.y / 4))
	camera.global_transform = source.global_transform
	camera.projection = source.projection
	camera.keep_aspect = source.keep_aspect
	camera.fov = source.fov
	camera.size = source.size
	camera.frustum_offset = source.frustum_offset
	camera.near = source.near
	camera.far = source.far
	camera.environment = source.environment
	render_target_update_mode = SubViewport.UPDATE_ONCE
