"""Open an exported mod as an editable workspace without overwriting local edits."""

import argparse
import hashlib
import json
import re
import subprocess
import tempfile
import zipfile
from collections.abc import Callable
from pathlib import Path

if __package__:
    from .validate_godot_mod import validate_dependencies
else:
    from validate_godot_mod import validate_dependencies


def archive_files(archive: zipfile.ZipFile) -> list[zipfile.ZipInfo]:
    entries = archive.infolist()
    if len(entries) > 10000 or sum(entry.file_size for entry in entries) > 2 * 1024**3:
        raise ValueError("Mod ZIP exceeds the 10000-file / 2 GiB limit")
    names = set()
    for entry in entries:
        parts = entry.orig_filename.rstrip("/").split("/")
        for part in parts:
            if (
                not part
                or part in (".", "..")
                or part.endswith((".", " "))
                or any(ord(char) < 32 or char in '<>:"\\|?*' for char in part)
                or re.match(
                    r"^(CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])(?:\.|$)", part, re.IGNORECASE
                )
            ):
                raise ValueError("Unsafe ZIP path: " + entry.filename)
        key = "/".join(parts).casefold()
        if key in {".editor-source.json", ".editor-workspace.json"}:
            raise ValueError(
                "Mod ZIP contains editor-local workspace metadata: " + entry.filename
            )
        if key in names or (entry.external_attr >> 16) & 0xF000 == 0xA000:
            raise ValueError("Duplicate path or symbolic link: " + entry.filename)
        names.add(key)
    return entries


def validate_references(manifest: dict, names: set[str]) -> None:
    for section, fields in {
        "stages": ["scene"],
        "replacements": ["path"],
        "materials": ["albedo", "normal", "orm", "emission"],
        "effects": ["material", "depth_shader"],
        "appearances": ["material"],
        "postprocess": ["effect"],
        "ui": ["scene"],
        "resources": ["path"],
    }.items():
        entries = manifest.get(section, {})
        if not isinstance(entries, dict):
            raise TypeError("Invalid manifest section: " + section)
        for entry in entries.values():
            if not isinstance(entry, dict):
                raise TypeError("Invalid manifest entry: " + section)
            for field in fields:
                if section == "materials" and field not in entry:
                    continue
                if not isinstance(entry.get(field), str) or entry[field] not in names:
                    raise ValueError("Missing mod resource: " + str(entry.get(field)))
    extensions = manifest.get("extensions", [])
    if not isinstance(extensions, list):
        raise TypeError("Invalid manifest extensions")
    for entry in extensions:
        if (
            not isinstance(entry, dict)
            or not isinstance(entry.get("path"), str)
            or entry["path"] not in names
        ):
            raise ValueError("Missing mod extension descriptor")


def exported_workspace(
    source: Path, mods: Path, digest: str, identity: str
) -> Path | None:
    matches = []
    if not mods.is_dir():
        return None
    for directory in mods.iterdir():
        state_path = directory / ".editor-workspace.json"
        manifest_path = directory / "mod.json"
        if (
            directory.is_symlink()
            or not state_path.is_file()
            or not manifest_path.is_file()
        ):
            continue
        try:
            state = json.loads(state_path.read_text(encoding="utf-8"))
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        except (ValueError, OSError):
            continue
        if (
            isinstance(state, dict)
            and isinstance(manifest, dict)
            and state.get("schema") == 1
            and state.get("id") == identity
            and manifest.get("id") == identity
            and state.get("export_sha256") == digest
            and isinstance(state.get("export_path"), str)
            and Path(state["export_path"]).resolve() == source.resolve()
        ):
            matches.append(directory)
    if len(matches) > 1:
        raise ValueError(
            "Multiple workspaces exported this ZIP. Select the intended workspace in the editor."
        )
    return matches[0] if matches else None


def archive_manifest(archive: zipfile.ZipFile, entries: list[zipfile.ZipInfo]) -> dict:
    manifest_entry = archive.getinfo("mod.json")
    if manifest_entry.file_size > 1024**2:
        raise ValueError("Mod manifest exceeds 1 MiB")
    manifest = json.loads(archive.read(manifest_entry))
    if (
        not isinstance(manifest, dict)
        or manifest.get("schema") != 1
        or not isinstance(manifest.get("id"), str)
        or not manifest["id"].strip()
    ):
        raise ValueError("ZIP requires a schema 1 mod.json with a nonempty ID")
    validate_references(
        manifest, {entry.filename for entry in entries if not entry.is_dir()}
    )
    damaged = archive.testzip()
    if damaged:
        raise ValueError("Damaged ZIP entry: " + damaged)
    return manifest


def resumed_workspace(
    source: Path, mods: Path, digest: str, identity: str
) -> Path | None:
    resumed = exported_workspace(source, mods, digest, identity)
    if resumed is not None:
        return resumed
    destination = workspace_path(source, mods, digest)
    if not destination.exists():
        return None
    marker = destination / ".editor-source.json"
    if marker.is_file() and (destination / "mod.json").is_file():
        provenance = json.loads(marker.read_text(encoding="utf-8"))
        if isinstance(provenance, dict) and provenance.get("sha256") == digest:
            return destination
    raise ValueError(
        "Workspace already exists without matching ZIP provenance: " + str(destination)
    )


def workspace_path(source: Path, mods: Path, digest: str) -> Path:
    name = re.sub(r"[^a-zA-Z0-9_-]", "_", source.stem)[:60]
    return mods / (name + "-" + digest[:16])


def open_mod(source: Path, mods: Path, validate: Callable[[Path], None]) -> Path:
    with source.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    with zipfile.ZipFile(source) as archive:
        entries = archive_files(archive)
        manifest = archive_manifest(archive, entries)
        resumed = resumed_workspace(source, mods, digest, manifest["id"])
        destination = workspace_path(source, mods, digest)
        mods.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix=".import-", dir=mods) as temporary:
            staging = Path(temporary) / "mod"
            staging.mkdir()
            for entry in entries:
                archive.extract(entry, staging)
            validate(staging)
            if resumed is not None:
                return resumed
            (staging / ".editor-source.json").write_text(
                json.dumps({"sha256": digest, "zip": str(source.resolve())}),
                encoding="utf-8",
            )
            staging.rename(destination)
    return destination


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("mods", type=Path)
    parser.add_argument("--godot", required=True, type=Path)
    parser.add_argument("--project", required=True, type=Path)
    args = parser.parse_args()
    try:
        result = open_mod(
            args.archive,
            args.mods,
            lambda directory: validate_dependencies(
                directory, args.godot, args.project
            ),
        )
        print(json.dumps({"path": str(result.resolve())}))
    except (
        OSError,
        ValueError,
        TypeError,
        KeyError,
        zipfile.BadZipFile,
        RuntimeError,
        subprocess.TimeoutExpired,
    ) as error:
        parser.exit(1, str(error) + "\n")


if __name__ == "__main__":
    main()
