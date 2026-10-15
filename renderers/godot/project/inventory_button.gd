@tool
extends Button

@export_enum("open","select","equip","use","close") var native_action := "select"
@export_enum("Current:-1","Items:0","Weapons:1") var native_side := -1
@export var native_target := -2
