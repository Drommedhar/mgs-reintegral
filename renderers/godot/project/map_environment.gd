@tool
extends RefCounted

const DEFAULT = preload("res://map_environment.tres")

static func find_in(root: Node) -> WorldEnvironment:
	for node in root.find_children("*", "WorldEnvironment", true, false):
		return node
	return null

static func create() -> WorldEnvironment:
	var node := WorldEnvironment.new()
	node.name = "MapEnvironment"
	node.environment = DEFAULT.duplicate(true)
	return node

static func attach(root: Node) -> WorldEnvironment:
	var existing := find_in(root)
	if existing != null: return existing
	var node := create()
	root.add_child(node)
	node.owner = root
	return node
