@tool
extends Control

@export var use_native_name := true
@export var use_native_icon := true
@export var normal_color := Color(0,0,0,0.5)
@export var highlight_color := Color(0,0,1,0.5)
@export var number_color := Color(87.0/128,87.0/128,87.0/128)
@export var empty_color := Color(1,0.25,0)

func sprite(node: TextureRect, art: RefCounted, index: int, origin: Vector2) -> void:
	if node.texture != null and not node.texture.has_meta("mgs_retail_derived"): return
	node.texture = art.textures[index]
	node.position += origin + art.offsets[index]
	node.size = node.texture.get_size()

func apply_native_state(state: Dictionary, art: RefCounted) -> void:
	var interact := get_node_or_null("Interact") as Button
	if interact!=null:
		interact.native_side=state.side
		interact.native_target=state.id
	get_node("Background").color = highlight_color if state.flags & 64 else normal_color
	var icon: TextureRect = get_node("Icon")
	icon.visible = icon.visible and state.id >= 0
	if icon.visible and use_native_icon: sprite(icon, art, state.icon, Vector2.ZERO)
	icon.self_modulate = Color(0.5,0.5,0.5) if state.flags & 32 else Color.WHITE
	var title: Label = get_node("Name")
	if use_native_name:
		var right := title.position.x + title.size.x
		title.text = state.name
		var width := title.get_theme_font("font").get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, title.get_theme_font_size("font_size")).x
		title.size.x = maxf(title.size.x, width)
		title.position.x = right - title.size.x
	title.visible = title.visible and not state.flags & 128
	var counter: Label = get_node("Count")
	counter.visible = counter.visible and bool(state.flags & (4|8|16))
	counter.add_theme_color_override("font_color", (empty_color if state.quantity == 0 else number_color) if state.flags & 4 else Color.WHITE)
	if state.flags & 4: counter.text = "%d/%d" % [state.quantity, state.maximum]
	elif state.flags & 8: counter.text = str(state.level)
	elif state.flags & 16: counter.text = str(state.quantity)
	get_node("Level").visible = get_node("Level").visible and bool(state.flags & 8)
	if state.flags & 8: counter.position += Vector2(18,1)
	elif state.flags & 16: counter.position += Vector2(10,-1)
	for pair in [["Disabled",1,40], ["Frozen",2,48]]:
		var badge: TextureRect = get_node(pair[0])
		badge.visible = badge.visible and bool(state.flags & pair[1])
		if badge.visible: sprite(badge, art, pair[2], Vector2(-2,6))
	var magazine: Control = get_node("Magazine")
	magazine.art = art
	magazine.state = state
	magazine.visible = magazine.visible and bool(state.flags & 128)
	magazine.queue_redraw()
