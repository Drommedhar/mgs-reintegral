"""Inventory configured presentation content without exporting original assets."""

import argparse
import hashlib
import json
from collections import Counter
from pathlib import Path

from tools.list_assets import list_assets, read_at, stage_table

RESIDENT_STAGES = {"init", "init_tux", "init_ve"}
SERIALS = {1: "SLPM_862.47", 2: "SLPM_862.48"}


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def prepared_stages(catalog: dict, disc: int, receipt: dict) -> set[str]:
    if catalog.get("disc") != disc:
        return set()
    if (
        catalog.get("schema") != 1
        or catalog.get("edition") != "integral-j"
        or catalog.get("sourceImageSha256") != receipt["image"]["sha256"]
    ):
        raise ValueError("Prepared catalog does not match its original disc")
    prefix = f"mgs/integral-j/disc{disc}/stage/"
    stages = set()
    for identity in catalog["assets"]:
        if not identity.startswith(prefix):
            raise ValueError(
                f"Prepared catalog has an inconsistent asset ID: {identity}"
            )
        parts = identity[len(prefix) :].split("/")
        if len(parts) != 2 or not all(parts):
            raise ValueError(f"Invalid prepared asset ID: {identity}")
        stages.add(parts[0])
    return stages


def disc_inventory(
    content: Path, disc: int, configured: set[str], catalog: dict
) -> dict:
    receipt = json.loads((content / "manifest.json").read_text(encoding="utf-8"))
    if receipt["serial"] != SERIALS[disc]:
        raise ValueError(f"Disc {disc} requires {SERIALS[disc]}")
    source = content / "MGS/STAGE.DIR"
    source_hash = digest(source)
    expected = next(
        item["sha256"] for item in receipt["files"] if item["path"] == "MGS/STAGE.DIR"
    )
    if source_hash != expected:
        raise ValueError(f"Disc {disc} STAGE.DIR differs from its import receipt")
    prepared = prepared_stages(catalog, disc, receipt)
    if catalog.get("disc") == disc and catalog.get("stageDirSha256") != source_hash:
        raise ValueError("Prepared catalog uses a different STAGE.DIR")
    records = []
    with source.open("rb") as stream:
        size = source.stat().st_size
        names = stage_table(stream, size)
        for name in sorted(names):
            assets = list_assets(source, name)
            scripts = [
                {
                    "resource": asset.identity,
                    "sha256": hashlib.sha256(
                        read_at(stream, asset.offset, asset.size, size)
                    ).hexdigest(),
                    "bytes": asset.size,
                }
                for asset in assets
                if asset.identity.endswith(".g")
            ]
            scope = (
                "configured"
                if name in configured
                else "resident"
                if name in RESIDENT_STAGES
                else "unconfigured"
            )
            records.append(
                {
                    "stage": name,
                    "scope": scope,
                    "resource_counts": dict(
                        sorted(Counter(a.identity[-1] for a in assets).items())
                    ),
                    "scripts": scripts,
                    "prepared_catalog_entry": name in prepared,
                    "presentation_acceptance": "unverified",
                }
            )
    return {
        "disc": disc,
        "serial": receipt["serial"],
        "source_image_sha256": receipt["image"]["sha256"],
        "stage_dir_sha256": source_hash,
        "stages": records,
    }


def load_catalogs(paths: list[Path]) -> dict[int, tuple[dict, str]]:
    catalogs = {}
    for path in paths:
        catalog = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(catalog, dict) or catalog.get("disc") not in SERIALS:
            raise ValueError("Prepared catalog must identify a supported campaign disc")
        disc = catalog["disc"]
        if disc in catalogs:
            raise ValueError(f"Duplicate prepared catalog for disc {disc}")
        catalogs[disc] = (catalog, digest(path))
    return catalogs


def inventory(
    content: Path, configuration: Path, catalog_paths: Path | list[Path] | None
) -> dict:
    configured = json.loads(configuration.read_text(encoding="utf-8"))["stages"]
    if len(configured) != len(set(configured)):
        raise ValueError("Configured stages contain duplicate names")
    paths = [catalog_paths] if isinstance(catalog_paths, Path) else catalog_paths or []
    catalogs = load_catalogs(paths)
    discs = [
        disc_inventory(
            content / f"disc{disc}",
            disc,
            set(configured),
            catalogs.get(disc, ({}, ""))[0],
        )
        for disc in SERIALS
    ]
    present = {stage["stage"] for disc in discs for stage in disc["stages"]}
    return {
        "schema": "mgs.presentation.coverage.v1",
        "configuration_sha256": digest(configuration),
        "configured_stages": sorted(configured),
        "configured_missing_from_both_discs": sorted(set(configured) - present),
        "prepared_catalog_sha256": next(iter(catalogs.values()))[1]
        if len(catalogs) == 1
        else None,
        "prepared_catalogs": [
            {"disc": disc, "sha256": catalogs[disc][1]} for disc in sorted(catalogs)
        ],
        "discs": discs,
        "summary": {
            "configured": len(configured),
            "disc_stage_entries": sum(len(disc["stages"]) for disc in discs),
            "catalogued_entries": sum(
                stage["prepared_catalog_entry"]
                for disc in discs
                for stage in disc["stages"]
            ),
            "verified_presentation_entries": 0,
        },
        "limits": "Resource presence and a prepared catalog entry do not prove scene assembly, active actor declarations, rendering or playability. This inventory does not execute conditional scripts or export original data.",
    }


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--content", type=Path, default=root / ".local/content")
    parser.add_argument(
        "--configuration", type=Path, default=root / "config/stages.json"
    )
    parser.add_argument(
        "--catalog",
        type=Path,
        action="append",
        default=[],
        help="Prepared catalog; repeat for each disc",
    )
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = inventory(args.content, args.configuration, args.catalog)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result["summary"]))


if __name__ == "__main__":
    main()
