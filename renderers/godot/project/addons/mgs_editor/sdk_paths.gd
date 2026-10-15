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

static func prepare_python() -> String:
	if packaged():
		var output: Array = []
		var result := OS.execute(powershell(), ["-NoProfile", "-ExecutionPolicy", "Bypass",
			"-File", root().path_join("tools/prepare-python.ps1")], output, true)
		if result != 0: return "Cannot prepare Python: " + "\n".join(output)
	if not FileAccess.file_exists(python()):
		return "Python importer is missing: " + python() + ". Run tools/bootstrap.ps1 in a source checkout."
	return ""
