@tool
extends RefCounted

var visited: Dictionary = {}

func mark_model(node: Node) -> void:
	mark_properties(node)
	for child in node.get_children(): mark_model(child)

func mark_properties(object: Object) -> void:
	for property in object.get_property_list():
		if property.usage & PROPERTY_USAGE_STORAGE and property.name != "script": mark_value(object.get(property.name))

func mark_value(value: Variant) -> void:
	if value is Resource:
		var identity: int = value.get_instance_id()
		if visited.has(identity): return
		visited[identity] = true
		if value is Mesh or value is Skin or value is Texture or value is Image or value is Font or value is Animation or value is AnimationLibrary:
			value.set_meta("mgs_retail_derived", true)
		mark_properties(value)
	elif value is Array:
		for item in value: mark_value(item)
	elif value is Dictionary:
		for key in value:
			mark_value(key)
			mark_value(value[key])
