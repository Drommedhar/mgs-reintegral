extends RefCounted

signal gpu_finished(target: RID, error: String)

var runtime: Node
var _window: Dictionary = {}
var _scale := 1

static func render_factor(dimensions: Vector2i, widescreen: bool, scene: bool) -> int:
	var horizontal := dimensions.x / 320.0
	var vertical := dimensions.y / (224.0 if widescreen and not scene else 240.0)
	return clampi(ceili(minf(horizontal, vertical) if scene else maxf(horizontal, vertical)), 1, 8)

static func legacy_rectangle(dimensions: Vector2i, aspect: float) -> Rect2i:
	var size := dimensions
	if float(dimensions.x) / dimensions.y > aspect:
		size.x = int(dimensions.y * aspect + 0.5)
	else:
		size.y = int(dimensions.x / aspect + 0.5)
	return Rect2i(Vector2i((dimensions - size) / 2), size)

static func fullscreen() -> bool:
	return DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]

func _gpu(method: String, arguments: Array = []) -> Array:
	if runtime.shutting_down: return [RID(), "Renderer is closing"]
	arguments.append(func(target: RID, error: String): gpu_finished.emit(target, error))
	RenderingServer.call_on_render_thread(Callable(runtime.gpu, method).bindv(arguments))
	return await gpu_finished

func prepare(values: Dictionary) -> String:
	_window = {"mode":DisplayServer.window_get_mode(), "size":DisplayServer.window_get_size(), "position":DisplayServer.window_get_position()}
	_scale = runtime.gpu.render_scale
	var dimensions := extent(values)
	var factor := render_factor(dimensions, values["display.widescreen"], runtime.scene_enabled)
	var result := await _gpu("prepare_display", [factor])
	return result[1]

func commit(values: Dictionary, reference: bool) -> String:
	var result := await _gpu("commit_display")
	if not result[1].is_empty(): return result[1]
	if runtime.shutting_down: return "Renderer is closing"
	_activate(result[0], values, reference)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if values["display.fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED)
	if not values["display.fullscreen"]: DisplayServer.window_set_size(extent(values))
	for tick in 2: await runtime.get_tree().process_frame
	if fullscreen() != values["display.fullscreen"]: return "Window system rejected fullscreen change"
	if not fullscreen() and DisplayServer.window_get_size() != extent(values): return "Window system rejected window size"
	return ""

func discard() -> String:
	var result := await _gpu("discard_display")
	return result[1]

func finish(restore: bool, values: Dictionary, reference: bool) -> String:
	var result := await _gpu("finish_display", [restore])
	if not result[1].is_empty(): return result[1]
	if runtime.shutting_down: return "Renderer is closing"
	if restore:
		_activate(result[0], values, reference)
		DisplayServer.window_set_mode(_window.mode)
		if _window.mode == DisplayServer.WINDOW_MODE_WINDOWED:
			DisplayServer.window_set_size(_window.size)
			DisplayServer.window_set_position(_window.position)
		for tick in 2: await runtime.get_tree().process_frame
		if DisplayServer.window_get_mode() != _window.mode: return "Window mode restoration failed"
		if _window.mode == DisplayServer.WINDOW_MODE_WINDOWED and DisplayServer.window_get_size() != _window.size:
			return "Window size restoration failed"
	_window = {}
	return ""

static func extent(values: Dictionary) -> Vector2i:
	var parts: PackedStringArray = values["display.resolution"].split("x")
	return Vector2i(int(parts[0]), int(parts[1]))

func _activate(target: RID, values: Dictionary, reference: bool) -> void:
	runtime.texture.texture_rd_rid = target
	var ratio: float = float(runtime.gpu.render_scale) / _scale
	runtime.atlas.region = Rect2(runtime.atlas.region.position * ratio, runtime.atlas.region.size * ratio)
	_scale = runtime.gpu.render_scale
	var dimensions := extent(values)
	var wide: bool = values["display.widescreen"] and not reference
	runtime.aspect = float(dimensions.x) / dimensions.y if wide else 4.0 / 3.0
	runtime.scene_view.horizontal_scale = (4.0 * dimensions.y) / (3.0 * dimensions.x) if wide else 1.0
	var world_size: Vector2i = runtime.scene_view.render_extent(maxi(2, runtime.gpu.render_scale))
	runtime.world_viewport.size = world_size
	runtime.metadata_viewport.size = world_size
	runtime.vision_cut = true
	runtime.scene_dirty = true
	runtime.resize_screen()
