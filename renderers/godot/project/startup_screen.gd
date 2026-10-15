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
var status := Label.new()

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
	status.text = "Checking prepared assets…"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.clip_text = true
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	background.add_child(status)
	get_viewport().size_changed.connect(fit)
	fit()
	refresh()

func fit() -> void:
	background.size = get_viewport().get_visible_rect().size
	var scale := clampf(background.size.y / 1080.0, 0.5, 2.0)
	var pixel_scale := maxi(1, roundi(2.0 * scale))
	animation.size = Vector2(80, 70) * pixel_scale
	animation.position = (background.size - animation.size - Vector2(32, 28) * scale).round()
	status.add_theme_font_size_override("font_size", maxi(12, roundi(20 * scale)))
	status.position = Vector2(32 * scale, animation.position.y)
	status.size = Vector2(maxf(0, animation.position.x - 48 * scale), animation.size.y)

func refresh() -> void:
	var next := black and (startup or native_loading or preparing)
	if next != active: elapsed = 0.0
	active = next
	visible = active
	background.color = Color.BLACK if startup else Color.TRANSPARENT
	animation.visible = active and elapsed >= APPEAR_DELAY
	status.visible = startup and animation.visible

func _process(delta: float) -> void:
	if not active: return
	elapsed += delta
	animation.visible = elapsed >= APPEAR_DELAY
	status.visible = startup and animation.visible
	var frame := int(maxf(0.0, elapsed - APPEAR_DELAY) / FRAME_SECONDS) % FRAME_COUNT
	animation.material.set_shader_parameter("animation_frame", frame)

func set_loading(loading: bool, assembling: bool, display_black: bool) -> void:
	native_loading = loading
	preparing = assembling
	black = display_black
	refresh()

func update_phase(next_phase: int, message: String, fraction: float = -1.0) -> void:
	if not startup or next_phase < phase: return
	phase = next_phase
	status.text = message + (" (%d%%)" % roundi(clampf(fraction, 0.0, 1.0) * 100.0) if fraction >= 0 else "")

func finish() -> void:
	startup = false
	refresh()
