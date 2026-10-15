@tool
extends RefCounted

const PROCESS = preload("snow_process.gdshader")
var draw := GPUParticles3D.new()
var heightfield := GPUParticlesCollisionHeightField3D.new()
var process := ShaderMaterial.new()
var time := 0.0
var pending_time := 0.0

func initialize(volume: Node3D, material: ShaderMaterial) -> void:
	draw.name = "GPUFlakes"
	draw.local_coords = true
	# Native ticks request simulation explicitly, including while the editor/render loop keeps running.
	draw.speed_scale = 0.0
	draw.fixed_fps = 0
	draw.interpolate = false
	draw.fract_delta = false
	draw.explosiveness = 1.0
	draw.lifetime = 3600.0
	draw.use_fixed_seed = true
	draw.draw_pass_1 = QuadMesh.new()
	draw.draw_pass_1.size = Vector2.ONE
	draw.material_override = material
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	process.shader = PROCESS
	draw.process_material = process
	heightfield.name = "WeatherCollision"
	heightfield.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_WHEN_MOVED
	volume.add_child(draw)
	volume.add_child(heightfield)

func reset(volume: Node3D) -> void:
	time = 0.0
	pending_time = 0.0
	draw.amount = maxi(volume.amount, 1)
	draw.seed = volume.random_seed
	draw.visibility_aabb = AABB(-volume.volume_size * 0.5, volume.volume_size).grow(volume.flake_size.y)
	heightfield.size = volume.volume_size
	heightfield.heightfield_mask = volume.weather_collision_mask
	heightfield.resolution = volume.weather_collision_resolution
	draw.restart(true)

func advance(delta: float) -> void:
	time += delta
	pending_time += delta

func flush(volume: Node3D) -> void:
	draw.visible = volume.active() and volume.amount > 0
	heightfield.visible = draw.visible
	if not draw.visible:
		pending_time = 0.0
		return
	heightfield.heightfield_mask = volume.weather_collision_mask
	heightfield.resolution = volume.weather_collision_resolution
	for key in ["volume_size", "flake_size", "fall_speed", "speed_variation", "wind_velocity", "gust_strength", "gust_speed", "flutter_strength", "flutter_speed", "settle_time", "prewarm"]:
		process.set_shader_parameter(key, volume.get(key))
	draw.collision_base_size = volume.contact_offset
	if pending_time > 0.0:
		RenderingServer.particles_collision_height_field_update(heightfield.get_base())
		draw.request_particles_process(pending_time)
		pending_time = 0.0

func release() -> void:
	draw.free()
	heightfield.free()
