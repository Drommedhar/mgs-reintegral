@tool
extends RefCounted

const GROUP = "EventLightTemplates"
const PATH_META = "mgs_event_light_templates_path"
const NAMES = {1: "TemporaryFlash", 2: "WeaponSpot", 3: "AlarmSpot", 4: "AlarmFill"}

static func find_in(overlay: Node3D) -> Node:
	return overlay.get_node_or_null(overlay.get_meta(PATH_META, NodePath(GROUP))) if overlay != null else null

static func create_alarm() -> SpotLight3D:
	var alarm := SpotLight3D.new()
	alarm.name = NAMES[3]
	alarm.light_color = Color(1.0, 0.025, 0.01)
	alarm.light_energy = 5.0
	alarm.spot_range = 7.0
	alarm.spot_angle = 24.0
	alarm.shadow_enabled = true
	alarm.shadow_bias = 0.03
	alarm.shadow_normal_bias = 0.1
	alarm.editor_description = "Two opposing red spotlights per patrol beacon. Native beam transforms control rotation and activation; local -Z points forward."
	return alarm

static func create_alarm_fill() -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = NAMES[4]
	light.light_color = Color(1.0, 0.025, 0.01)
	light.light_energy = 0.35
	light.omni_range = 6.0
	light.omni_attenuation = 1.0
	light.shadow_enabled = true
	light.shadow_bias = 0.03
	light.shadow_normal_bias = 0.1
	light.editor_description = "Gentle red spill around each active beacon. One omni light per beacon; the two AlarmSpot lights rotate separately."
	return light

static func add_missing_alarms(group: Node, owner: Node = null) -> bool:
	var changed := false
	for kind in [3, 4]:
		if group.has_node(NAMES[kind]): continue
		var light: Light3D = create_alarm() if kind == 3 else create_alarm_fill()
		group.add_child(light)
		light.owner = owner
		changed = true
	return changed

static func create() -> Node3D:
	var group := Node3D.new()
	group.name = GROUP
	group.hide()
	group.editor_description = "Light templates spawned by native game events. Show this group to preview; runtime always hides the templates. Child visibility enables/disables that event light."
	var flash := OmniLight3D.new()
	flash.name = NAMES[1]
	flash.omni_range = 4.0
	flash.omni_attenuation = 1.0
	flash.light_energy = 2.0
	flash.editor_description = "Native muzzle flashes, impacts and other temporary lights. Range caps the original animated radius; native code controls position and lifetime."
	var weapon := SpotLight3D.new()
	weapon.name = NAMES[2]
	weapon.spot_range = 8.0
	weapon.spot_angle = 22.0
	weapon.light_energy = 2.0
	weapon.editor_description = "Attached to the original famas_l weapon point, aiming down the barrel. Transform offsets are local to the attachment; -Z points forward. Native visibility controls its lifetime."
	for light in [flash, weapon]:
		light.shadow_enabled = true
		light.shadow_bias = 0.03
		light.shadow_normal_bias = 0.1
		group.add_child(light)
	add_missing_alarms(group)
	return group

static func attach(overlay: Node3D) -> bool:
	var existing := find_in(overlay)
	if existing != null:
		return add_missing_alarms(existing, overlay)
	var group := create()
	overlay.add_child(group)
	group.owner = overlay
	for light in group.get_children(): light.owner = overlay
	return true

static func validate(group: Node) -> String:
	if not group is Node3D: return "EventLightTemplates must be Node3D"
	for kind in NAMES:
		var light := group.get_node_or_null(NodePath(NAMES[kind]))
		# Older mod ZIPs predate the alarm template and use its built-in defaults.
		if kind in [3, 4] and light == null: continue
		if kind in [1, 4] and not light is OmniLight3D: return NAMES[kind] + " must be OmniLight3D"
		if kind in [2, 3] and not light is SpotLight3D: return NAMES[kind] + " must be SpotLight3D"
		if not light.transform.is_finite(): return "Invalid event light transform"
	return ""
