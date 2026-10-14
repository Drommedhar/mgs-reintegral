@tool
extends Button

@export_enum("select", "activate", "back") var native_action := "activate"
@export_range(0,4) var native_target := 0
@export_enum("Back:0", "Branding:1", "Press Start:6", "Main menu:7", "Save space:18", "Difficulty:21") var native_page := 7
