extends Node3D

signal activated(value: int)
@onready var marker: Node3D = $Marker
var received := 0

func _ready() -> void:
	activated.emit(7)

func receive(value: int) -> void:
	received = value
