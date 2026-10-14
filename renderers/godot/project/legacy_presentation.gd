extends SubViewport

class Blit extends Node2D:
	var source: Texture2D
	var extent := Vector2i.ONE
	func _draw() -> void:
		draw_primitive(PackedVector2Array([Vector2.ZERO, Vector2(extent.x * 2, 0), Vector2(0, extent.y * 2)]),
			PackedColorArray([Color.WHITE]), PackedVector2Array([Vector2.ZERO, Vector2(2, 0), Vector2(0, 2)]), source)

var blit := Blit.new()

func _init() -> void:
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(blit)

func initialize(source: Texture2D, filtering: CanvasItem.TextureFilter) -> void:
	blit.source = source
	blit.texture_filter = filtering
	var material := ShaderMaterial.new()
	material.shader = preload("res://legacy_present.gdshader")
	blit.material = material
	render_target_update_mode = SubViewport.UPDATE_ALWAYS

func configure(region: Rect2, extent: Vector2i) -> void:
	if blit.source == null: return
	if extent != size:
		size = extent
	if extent != blit.extent:
		blit.extent = extent
		blit.queue_redraw()
	blit.material.set_shader_parameter("source_region", Vector4(region.position.x, region.position.y, region.size.x, region.size.y))
