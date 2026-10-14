@tool
extends RefCounted

static func root() -> String:
	return ProjectSettings.globalize_path("res://../../..").simplify_path()

static func packaged() -> bool:
	return FileAccess.file_exists(root().path_join("sdk.json"))

static func python() -> String:
	if packaged(): return root().path_join(".tools/python/python.exe")
	return root().path_join(".venv/Scripts/python.exe" if OS.has_feature("windows") else ".venv/bin/python")

static func powershell() -> String:
	return root().path_join(".tools/powershell/pwsh.exe") if packaged() else "pwsh.exe"
