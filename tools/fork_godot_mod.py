"""Save an editable mod workspace as a separate mod without altering its source."""

import argparse
import json
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

TEXT_RESOURCES = {
    ".gd",
    ".tscn",
    ".tres",
    ".gdshader",
    ".gdshaderinc",
    ".json",
    ".gdextension",
    ".gltf",
}
LOCAL_FILES = {".editor-source.json", ".editor-workspace.json"}
LOCAL_DIRECTORIES = {".godot", ".git", ".generated"}


def text_resources(
    source: Path, paths: list[Path], project: Path, output: Path, godot: Path | None
) -> dict[Path, Path]:
    binaries = [path for path in paths if path.suffix.lower() in {".res", ".scn"}]
    if not binaries:
        return {}
    if godot is None or not godot.is_file():
        raise ValueError(
            "Save As needs the Godot executable to relocate binary resources."
        )
    request = output / "resources.json"
    request.write_text(json.dumps([str(path) for path in binaries]), encoding="utf-8")
    result = subprocess.run(
        [
            str(godot),
            "--headless",
            "--path",
            str(project),
            "--script",
            "res://addons/mgs_editor/resource_conversion.gd",
            "--",
            str(request),
            str(output),
        ],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
        creationflags=subprocess.CREATE_NO_WINDOW
        if hasattr(subprocess, "CREATE_NO_WINDOW")
        else 0,
    )
    if result.returncode != 0:
        raise ValueError(
            "Cannot relocate binary resources: " + result.stdout + result.stderr
        )
    converted = {}
    for index, path in enumerate(binaries):
        extension = ".tscn" if path.suffix.lower() == ".scn" else ".tres"
        target = path.with_suffix(extension)
        if target.exists():
            raise ValueError(
                "Converted resource would replace an existing file: "
                + str(target.relative_to(source))
            )
        text = output / (str(index) + extension)
        if not text.is_file():
            raise ValueError("Godot did not convert resource: " + str(path))
        converted[path] = text
    return converted


def relocate_text(
    text: str,
    source_file: Path,
    source: Path,
    project: Path,
    destination: Path,
    converted: dict[Path, Path],
) -> str:
    def relocate(match):
        value = match[2]
        if value.startswith("res://"):
            path = project / value.removeprefix("res://")
        elif value.startswith(("uid://", "user://")):
            return match[0]
        else:
            path = source_file.parent / value
        try:
            path = path.resolve()
        except (ValueError, OSError):
            return match[0]
        if path in converted:
            value = value.rsplit(".", 1)[0] + converted[path].suffix
        source_uri = "res://" + source.relative_to(project).as_posix() + "/"
        destination_uri = "res://" + destination.relative_to(project).as_posix() + "/"
        value = value.replace(source_uri, destination_uri)
        return match[1] + value + match[1]

    return re.sub(r"""(["'])([^"'\n]*)\1""", relocate, text)


def fork_mod(
    source: Path,
    destination: Path,
    project: Path,
    identity: str,
    name: str,
    godot: Path | None = None,
) -> Path:
    source, destination, project = (
        source.resolve(),
        destination.resolve(),
        project.resolve(),
    )
    if not re.fullmatch(r"[a-z][a-z0-9._-]{0,63}", identity):
        raise ValueError(
            "Use a mod ID beginning with a letter, followed by lowercase letters, digits, dots, dashes or underscores (up to 64 characters)."
        )
    if not name.strip():
        raise ValueError("Enter a name for the new mod.")
    if destination.exists() or destination.is_relative_to(source):
        raise ValueError("Choose a new workspace folder outside the source mod.")
    source.relative_to(project)
    destination.relative_to(project)
    manifest = json.loads((source / "mod.json").read_text(encoding="utf-8"))
    if (
        not isinstance(manifest, dict)
        or manifest.get("schema") != 1
        or not manifest.get("id")
    ):
        raise ValueError("Source workspace needs a schema 1 mod manifest.")
    if identity == manifest["id"]:
        raise ValueError(
            "Save As needs a different mod ID; use Save workspace to keep this mod."
        )
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(
        prefix=".fork-", dir=destination.parent
    ) as temporary:
        staging = Path(temporary) / "mod"
        staging.mkdir()
        paths = []
        for path in source.rglob("*"):
            relative = path.relative_to(source)
            if (
                any(part in LOCAL_DIRECTORIES for part in relative.parts)
                or path.name in LOCAL_FILES
                or path.suffix in {".uid", ".import"}
            ):
                continue
            if path.is_symlink():
                raise ValueError(
                    "Cannot copy a workspace symbolic link: " + str(relative)
                )
            if path.is_file():
                paths.append(path)
        converted = text_resources(source, paths, project, Path(temporary), godot)
        for path in paths:
            relative = path.relative_to(source)
            target = staging / relative
            if path in converted:
                target = target.with_suffix(converted[path].suffix)
            target.parent.mkdir(parents=True, exist_ok=True)
            if path.suffix in TEXT_RESOURCES or path in converted:
                text = converted.get(path, path).read_text(encoding="utf-8")
                text = relocate_text(
                    text, path, source, project, destination, converted
                )
                if target.suffix in {".tscn", ".tres"}:
                    text = re.sub(r' uid="uid://[^"]+"', "", text)
                target.write_text(text, encoding="utf-8")
            else:
                shutil.copyfile(path, target)
        manifest = json.loads((staging / "mod.json").read_text(encoding="utf-8"))
        manifest["id"], manifest["name"] = identity, name.strip()
        (staging / "mod.json").write_text(
            json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
        )
        staging.rename(destination)
    return destination


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("project", type=Path)
    parser.add_argument("identity")
    parser.add_argument("name")
    parser.add_argument("--godot", type=Path)
    args = parser.parse_args()
    try:
        print(
            json.dumps(
                {
                    "path": str(
                        fork_mod(
                            args.source,
                            args.destination,
                            args.project,
                            args.identity,
                            args.name,
                            args.godot,
                        )
                    )
                }
            )
        )
    except (OSError, ValueError, TypeError) as error:
        parser.exit(1, str(error) + "\n")


if __name__ == "__main__":
    main()
