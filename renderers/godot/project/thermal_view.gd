extends SubViewport

var camera := Camera3D.new()
var capture := preload("res://depth_capture.gd").new(false, true)

func initialize(source: SubViewport) -> void:
	world_3d = source.find_world_3d()
	transparent_bg = true
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	preload("res://scene_view.gd").configure_metadata(self)
	camera.cull_mask = preload("res://thermal_sources.gd").LAYER
	camera.environment = Environment.new()
	camera.environment.background_mode = Environment.BG_COLOR
	camera.environment.background_color = Color.BLACK
	var compositor := Compositor.new()
	compositor.compositor_effects = [capture]
	camera.compositor = compositor
	add_child(camera)
	camera.current = true

func render(source: Camera3D, extent: Vector2i, active: bool) -> void:
	if not active:
		render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	size = extent
	camera.global_transform = source.global_transform
	for property in ["projection", "keep_aspect", "fov", "size", "frustum_offset", "h_offset", "v_offset", "near", "far"]:
		camera.set(property, source.get(property))
	render_target_update_mode = SubViewport.UPDATE_ONCE
