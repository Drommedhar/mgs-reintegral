"""Open an exported mod as an editable workspace without overwriting local edits."""

import argparse
import hashlib
import json
import re
import tempfile
import zipfile
from pathlib import Path


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
        if key in names or (entry.external_attr >> 16) & 0xF000 == 0xA000:
            raise ValueError("Duplicate path or symbolic link: " + entry.filename)
        names.add(key)
    return entries


def validate_references(manifest: dict, names: set[str]) -> None:
    for section, fields in {
        "stages": ["scene"],
        "replacements": ["path"],
        "materials": ["albedo", "normal", "orm", "emission"],
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


def open_mod(source: Path, mods: Path) -> Path:
    with source.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    with zipfile.ZipFile(source) as archive:
        entries = archive_files(archive)
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
        name = re.sub(r"[^a-zA-Z0-9_-]", "_", source.stem)[:60]
        destination = mods / (name + "-" + digest[:16])
        marker = destination / ".editor-source.json"
        if destination.exists():
            if (
                marker.is_file()
                and (destination / "mod.json").is_file()
                and json.loads(marker.read_text(encoding="utf-8")).get("sha256")
                == digest
            ):
                return destination
            raise ValueError(
                "Workspace already exists without matching ZIP provenance: "
                + str(destination)
            )
        # Validate CRCs before creating a workspace that the editor can open.
        damaged = archive.testzip()
        if damaged:
            raise ValueError("Damaged ZIP entry: " + damaged)
        mods.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix=".import-", dir=mods) as temporary:
            staging = Path(temporary) / "mod"
            staging.mkdir()
            for entry in entries:
                archive.extract(entry, staging)
            (staging / marker.name).write_text(
                json.dumps({"sha256": digest, "zip": str(source.resolve())}),
                encoding="utf-8",
            )
            staging.rename(destination)
    return destination


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("mods", type=Path)
    args = parser.parse_args()
    try:
        print(json.dumps({"path": str(open_mod(args.archive, args.mods).resolve())}))
    except (
        OSError,
        ValueError,
        TypeError,
        KeyError,
        zipfile.BadZipFile,
        RuntimeError,
    ) as error:
        parser.exit(1, str(error) + "\n")


if __name__ == "__main__":
    main()
