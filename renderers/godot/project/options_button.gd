@tool
extends Button

@export_enum("select", "set", "activate", "back") var native_action := "select"
@export_range(0,10) var native_option := 0
@export_range(0,2) var native_value := 0
