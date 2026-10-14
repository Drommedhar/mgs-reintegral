extends RefCounted

var original_environment: Environment
var cut_environment: Environment

func begin(camera: Camera3D) -> void:
	var viewport := camera.get_viewport()
	if viewport.scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR2 or viewport.use_taa:
		# Godot c971f93e7 has no FSR2 reset API. This server setter rebuilds
		# render buffers once, including FSR2/TAA history, without changing settings.
		RenderingServer.viewport_set_fsr_sharpness(viewport.get_viewport_rid(), viewport.fsr_sharpness)
	camera.reset_physics_interpolation()
	var environment := camera.environment
	if environment == null: environment = camera.get_world_3d().environment
	if environment == null: environment = camera.get_world_3d().fallback_environment
	if environment != null and environment.volumetric_fog_enabled and environment.volumetric_fog_temporal_reprojection_enabled:
		original_environment = camera.environment
		cut_environment = environment.duplicate() as Environment
		# Keep history writes enabled so the following frame reprojects the new shot.
		cut_environment.volumetric_fog_temporal_reprojection_amount = 0.0
		camera.environment = cut_environment

func finish(camera: Camera3D) -> void:
	if cut_environment != null and camera.environment == cut_environment:
		camera.environment = original_environment
	cut_environment = null
	original_environment = null
