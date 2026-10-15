@tool
extends "res://original_ui_scene.gd"

const Ui = preload("res://radar_ui.gd")
const MapLayer = preload("res://radar_map_ui.gd")
func create(resources: RefCounted) -> Control:
	var art := preload("res://radar_art.gd").new()
	error = art.initialize(resources)
	if not error.is_empty(): return null
	root = Ui.new()
	root.name = "RadarUi"
	root.size = Vector2(320,224)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.set_meta("mgs_ui_slot", "radar")
	var panel := control(root, "Radar", Rect2(234,15,71,54))
	color(panel, "BorderLeft", Rect2(0,0,1,53), Color.BLACK)
	color(panel, "BorderTop", Rect2(0,0,70,1), Color.BLACK)
	color(panel, "BorderRight", Rect2(70,0,1,54), Color.BLACK)
	color(panel, "BorderBottom", Rect2(0,53,70,1), Color.BLACK)
	var interior := control(panel, "Interior", Rect2(1,1,69,52), true)
	create_map(interior)
	create_alert(interior)
	create_countdown(interior)
	return root

func create_map(interior: Control) -> void:
	var map := control(interior, "MapClip", Rect2(0,0,69,52), true)
	color(map, "Background", Rect2(0,0,69,52), root.map_background)
	for index in 3:
		var node := MapLayer.new()
		node.layer = index
		add(map, ["Walls", "Cones", "Contacts"][index], node, Rect2(34,26,69,52))
		if index == 1: blend(node, CanvasItemMaterial.BLEND_MODE_ADD)
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.BLACK, Color8(0,160,72)])
	var image := GradientTexture2D.new()
	image.gradient = gradient
	image.width = 24
	image.height = 1
	image.fill_to = Vector2(1,0)
	var sweep := texture(map, "RecoverySweep", Rect2(0,0,24,52))
	sweep.texture = image
	sweep.hide()
	blend(sweep, CanvasItemMaterial.BLEND_MODE_ADD)

func create_alert(interior: Control) -> void:
	var clip := control(interior, "AlertClip", Rect2(0,0,69,52), true)
	clip.hide()
	var panel := control(clip, "Panel", Rect2(0,0,69,52))
	color(panel, "Background", Rect2(0,0,69,52), root.alert_background)
	var noise := MapLayer.new()
	noise.layer = 3
	add(panel, "Noise", noise, Rect2(34,26,69,52))
	var foreground: Control = preload("res://radar_alert_ui.gd").new()
	add(panel, "Foreground", foreground, Rect2(0,0,69,52))
	blend(foreground, CanvasItemMaterial.BLEND_MODE_SUB)
	for entry in [["Header", Rect2(12,1,44,7)], ["Underline", Rect2(16,8,36,3)], ["Symbol", Rect2(9,14,28,12)]]:
		texture(foreground, entry[0], entry[1]).use_parent_material = true
	var counter := control(foreground, "Counter", Rect2(0,0,69,52))
	counter.use_parent_material = true
	for index in 4:
		texture(counter, "Digit%d" % index, Rect2([9,21,38,50][index],32,10,16)).use_parent_material = true
	for entry in [["Top",Rect2(7,29,55,1)], ["Bottom",Rect2(7,50,55,1)], ["Decimal",Rect2(33,46,3,2)]]:
		color(counter, entry[0], entry[1], Color8(137,37,24)).use_parent_material = true

func create_countdown(interior: Control) -> void:
	var node: Control = preload("res://radar_countdown_ui.gd").new()
	add(interior, "Countdown", node, Rect2(0,0,69,52))
	blend(node, CanvasItemMaterial.BLEND_MODE_SUB)
	node.hide()
	var background := color(node, "Background", Rect2(0,0,69,52), root.alert_background)
	background.show_behind_parent = true
	for entry in [["Warning",Rect2(0,1,72,11)], ["WarningText",Rect2(1,13,68,16)]]:
		var image := texture(node, entry[0], entry[1])
		blend(image, CanvasItemMaterial.BLEND_MODE_SUB)
