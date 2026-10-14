extends CanvasLayer

const APPEAR_DELAY = 0.25
const FRAME_SECONDS = 0.1
const FRAME_COUNT = 37
var phase := 0
var startup := true
var native_loading := false
var preparing := false
var black := true
var elapsed := 0.0
var active := false
var background := ColorRect.new()
var animation := TextureRect.new()

func _ready() -> void:
	layer = 90
	background.color = Color.BLACK
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var image := Image.new()
	var error := image.load_png_from_buffer(FileAccess.get_file_as_bytes("res://loading-snake.png"))
	if error != OK:
		push_error("Cannot load loading animation: " + error_string(error))
		get_tree().quit(1)
		return
	else:
		animation.texture = ImageTexture.create_from_image(image)
		var material := ShaderMaterial.new()
		material.shader = preload("res://loading_silhouette.gdshader")
		material.set_shader_parameter("animation_atlas", animation.texture)
		animation.material = material
	animation.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	animation.mouse_filter = Control.MOUSE_FILTER_IGNORE
	animation.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	animation.stretch_mode = TextureRect.STRETCH_SCALE
	background.add_child(animation)
	get_viewport().size_changed.connect(fit)
	fit()
	refresh()

func fit() -> void:
	background.size = get_viewport().get_visible_rect().size
	var scale := clampf(background.size.y / 1080.0, 0.5, 2.0)
	var pixel_scale := maxi(1, roundi(2.0 * scale))
	animation.size = Vector2(80, 70) * pixel_scale
	animation.position = (background.size - animation.size - Vector2(32, 28) * scale).round()

func refresh() -> void:
	var next := black and (startup or native_loading or preparing)
	if next != active: elapsed = 0.0
	active = next
	visible = active
	background.color = Color.BLACK if startup else Color.TRANSPARENT
	animation.visible = active and elapsed >= APPEAR_DELAY

func _process(delta: float) -> void:
	if not active: return
	elapsed += delta
	animation.visible = elapsed >= APPEAR_DELAY
	var frame := int(maxf(0.0, elapsed - APPEAR_DELAY) / FRAME_SECONDS) % FRAME_COUNT
	animation.material.set_shader_parameter("animation_frame", frame)

func set_loading(loading: bool, assembling: bool, display_black: bool) -> void:
	native_loading = loading
	preparing = assembling
	black = display_black
	refresh()

func update_phase(next_phase: int, _message: String, _fraction: float = -1.0) -> void:
	if startup: phase = maxi(phase, next_phase)

func finish() -> void:
	startup = false
	refresh()
