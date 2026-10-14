@tool
extends Control

@export_enum("Walls", "Cones", "Contacts", "Noise") var layer := 0
@export var wall_color := Color8(0, 160, 72)
@export var other_floor_wall_color := Color8(0, 64, 0)
@export var special_wall_color := Color8(180, 32, 64)
@export var player_color := Color8(200, 200, 200)
@export var contact_color := Color8(255, 100, 0)
@export var other_floor_contact_color := Color8(200, 0, 0)
@export var noise_color := Color8(0, 255, 128)
@export_range(0.1, 8) var line_width := 1.0
@export_range(0.1, 8) var contact_size := 1.0
var state: Dictionary = {}

func apply_native_state(value: Dictionary) -> void:
	state = value
	queue_redraw()

static func rgb(value: int) -> Color:
	return Color8(value & 255, (value >> 8) & 255, (value >> 16) & 255)

func _draw() -> void:
	if state.is_empty(): return
	if layer == 0:
		for wall in state.get("walls", []):
			var color: Color = [wall_color, other_floor_wall_color, special_wall_color][wall.kind]
			draw_line(wall.from, wall.to, color, line_width)
	elif layer == 1:
		for cone in state.get("sights", []):
			var bright := rgb(cone.color)
			var dark := rgb(cone.fade_color)
			draw_polygon(PackedVector2Array([cone.points[0], cone.points[1], cone.points[2]]), PackedColorArray([dark, bright, dark]))
			draw_polygon(PackedVector2Array([cone.points[1], cone.points[3], cone.points[2]]), PackedColorArray([bright, dark, dark]))
	elif layer == 2:
		for contact in state.get("contacts", []):
			var color: Color = [player_color, contact_color, other_floor_contact_color, noise_color][contact.kind]
			draw_rect(Rect2(contact.position, Vector2.ONE * contact_size), color)
			if contact.kind == 3:
				for point in contact.noise: draw_rect(Rect2(point, Vector2.ONE * contact_size), Color8(0, 200, 100))
	elif state.get("has_noise", 0):
		var seed_value: int = state.noise_seed
		var y := 0
		var color := rgb([0x181800, 0x48a000, 0x6e6e, 0xde][state.mode])
		color.a = 0.5
		while y < 52:
			var x := seed_value % 138 - 69
			draw_line(Vector2(x, y - 26), Vector2(x + int(seed_value / 256) % 69 + 8, y - 26), color, line_width)
			y += 4 + ((seed_value >> 24) & 7)
			seed_value = ((seed_value << 25) | (seed_value >> 7)) & 0xffffffff
