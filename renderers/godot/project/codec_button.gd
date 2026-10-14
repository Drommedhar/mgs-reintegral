@tool
extends Button

@export_enum("open","tune_step","call","memory","contact","confirm","advance","skip","back") var native_action := "call"
@export var native_target := 0
