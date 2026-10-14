"""Inspect package dependencies using the editor's exporter without importing assets."""

import json
import subprocess
from pathlib import Path


def validate_dependencies(directory: Path, godot: Path, project: Path) -> None:
    directory = directory.resolve()
    if not godot.is_file() or not (project / "project.godot").is_file():
        raise ValueError(
            "Mod dependency validation requires Godot and its SDK project."
        )
    report = directory.parent / "dependency-report.json"
    result = subprocess.run(
        [
            str(godot),
            "--headless",
            "--path",
            str(project),
            "--script",
            "res://addons/mgs_editor/validate_workspace.gd",
            "--",
            str(directory / "mod.json"),
            str(report),
        ],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
        timeout=90,
        creationflags=subprocess.CREATE_NO_WINDOW
        if hasattr(subprocess, "CREATE_NO_WINDOW")
        else 0,
    )
    data = json.loads(report.read_text(encoding="utf-8")) if report.is_file() else {}
    if not isinstance(data, dict) or not isinstance(data.get("error"), str):
        raise TypeError(
            "No dependency validation result: " + result.stdout + result.stderr
        )
    if data["error"]:
        raise ValueError(data["error"])
    if result.returncode != 0 or any(
        marker in result.stdout + result.stderr
        for marker in ("SCRIPT ERROR:", "SHADER ERROR:", "ERROR:")
    ):
        raise ValueError(
            "Dependency validation failed: " + result.stdout + result.stderr
        )
