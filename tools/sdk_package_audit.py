"""Check SDK inputs against the staged inventory and local original-content hashes."""

import hashlib
import io
import json
import zipfile
from pathlib import Path

PROJECT_RESOURCES = {
    "main.tscn",
    "map_environment.tres",
    "examples/lighting/lighting.tscn",
    "examples/layered_maps/shared/map.tscn",
    "examples/layered_maps/intro/map.tscn",
    "examples/named_resources/amber.tres",
    "examples/named_resources/marker.tscn",
    "examples/named_resources/teal.tres",
    "examples/presentation_camera/camera.tscn",
    "examples/presentation_camera/native_timeline.tscn",
    "examples/water_frost/preview.tscn",
    "examples/snow/preview.tscn",
    "addons/mgs_snow/snow_volume.tscn",
    "addons/mgs_water/water_region.tscn",
    "addons/mgs_water/pool.tscn",
    "addons/mgs_water/puddle.tscn",
    "addons/mgs_water/ocean.tscn",
    "addons/mgs_water/frost.tres",
}

REVIEWED_BINARY_ASSETS = {
    "renderers/godot/project/loading-snake.png": "7177639c30a52b363d30ab84048e75b0d35c2c22b9ea196d05df2cd6a1af96d8",
    "renderers/godot/project/interface-font.png": "5bca92a2076d111803717f425e5a900d69140a3bba1208168abfbdc9295f8d94",
    "renderers/godot/project/texgyreheros-regular.otf": "6ae1a09d5a940367b7aaaa91ee8bd8a2c333bfe193e7096e23f931357d62081f",
    "renderers/godot/project/re-integral-logo.png": "1c47659aa3bb77ac0e5251cc64038ee09f807d0b9b3d8aa5813d72975ba4d377",
    "renderers/godot/project/.generated/legacy-debug-font.bin": "b17e8983b9552a2243dfb55e8122ab880865e5001de409aad0e02204ed41a262",
}


def inspect_resource(relative: str, text: str) -> None:
    if relative not in PROJECT_RESOURCES:
        raise ValueError(f"SDK contains an unreviewed scene or resource: {relative}")
    if any(
        marker in text
        for marker in (
            "mgs_retail_derived",
            "mgs_editor_preview",
            "mgs_asset_id",
            "PackedByteArray(",
            '[sub_resource type="Image"',
        )
    ):
        raise ValueError(
            f"SDK resource contains original provenance or image data: {relative}"
        )


def original_hashes(local: Path) -> set[str]:
    hashes = set()
    catalogs = [
        local / name / "catalog.json"
        for name in ("godot-content", "godot-content-disc2")
    ]
    if not all(path.is_file() for path in catalogs):
        raise ValueError(
            "SDK packaging requires both prepared campaign provenance catalogs"
        )
    for path in catalogs:
        catalog = json.loads(path.read_text(encoding="utf-8"))
        for asset in catalog["assets"].values():
            hashes.add(asset["sha256"])
            hashes.update(asset["preparedFiles"].values())
        for clip in catalog.get("cinematics", {}).values():
            hashes.update(clip.get(field) for field in ("sha256", "preparedSha256"))
    for path in (local / "content").glob("disc*/manifest.json"):
        receipt = json.loads(path.read_text(encoding="utf-8"))
        hashes.update(entry["sha256"] for entry in receipt["files"])
    hashes.discard(None)
    return hashes


def known_original_hashes(local: Path | None = None) -> set[str]:
    baseline = Path(__file__).resolve().parents[1] / "config/sdk-original-sha256.txt"
    originals = set(baseline.read_text(encoding="ascii").splitlines())
    if not originals or any(
        len(value) != 64 or any(c not in "0123456789abcdef" for c in value)
        for value in originals
    ):
        raise ValueError("Invalid known-original fingerprint index")
    if local is not None:
        originals.update(original_hashes(local))
    return originals


def audit(root: Path, inventory: dict[str, str], local: Path | None = None) -> None:
    originals = known_original_hashes(local)
    actual = {
        path.relative_to(root).as_posix() for path in root.rglob("*") if path.is_file()
    }
    if actual != set(inventory):
        raise ValueError("SDK staging contains unlisted files or missing inputs")
    for relative, expected in inventory.items():
        path = root / relative
        with path.open("rb") as stream:
            digest = hashlib.file_digest(stream, "sha256").hexdigest()
        if digest != expected or digest in originals:
            raise ValueError(f"Changed SDK input or original-content copy: {relative}")
        if path.suffix == ".zip":
            inspect_archive(path.read_bytes(), relative, originals)
        parts = Path(relative).parts
        if any(part in {".local", ".godot", "mods", "__pycache__"} for part in parts):
            raise ValueError(f"SDK contains local content or caches: {relative}")
        if parts[0] == ".tools":
            raise ValueError(f"Downloaded tools must not be bundled: {relative}")
        if relative.startswith("renderers/godot/project/"):
            if (
                path.suffix.lower()
                in {
                    ".png",
                    ".jpg",
                    ".bin",
                    ".glb",
                    ".gltf",
                    ".ttf",
                    ".otf",
                    ".res",
                    ".scn",
                }
                and REVIEWED_BINARY_ASSETS.get(relative) != digest
            ):
                raise ValueError(
                    f"SDK project contains an unreviewed binary asset: {relative}"
                )
            if path.suffix in {".tscn", ".tres"}:
                inspect_resource(
                    relative.removeprefix("renderers/godot/project/"),
                    path.read_text(encoding="utf-8"),
                )


def inspect_archive(
    data: bytes, label: str, originals: set[str], depth: int = 0
) -> None:
    if depth > 5:
        raise ValueError(f"Unexpected nested tool archive: {label}")
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        for entry in archive.infolist():
            if entry.is_dir():
                continue
            contents = archive.read(entry)
            if hashlib.sha256(contents).hexdigest() in originals:
                raise ValueError(
                    f"Original-content copy inside SDK archive: {label}/{entry.filename}"
                )
            if entry.filename.lower().endswith(".zip"):
                inspect_archive(
                    contents, label + "/" + entry.filename, originals, depth + 1
                )
