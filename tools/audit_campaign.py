"""Audit selected native stage bindings against optional Integral stage archives."""

import argparse
import concurrent.futures
import json
import re
import struct
import subprocess
from pathlib import Path

from generate_sources import resolve_stages, source_paths
from list_assets import list_assets, stage_table


def preprocess(source: Path, project: Path, clang: Path) -> str:
    command = [
        str(clang),
        "--target=i686-pc-windows-msvc",
        "-E",
        "-P",
        "-DINTEGRAL",
        "-DMGS_NATIVE",
        "-D__psyz",
    ]
    for include in [
        "include",
        "vendor/mgs/source",
        "vendor/mgs/source/include",
        "vendor/psyz/psyz/include",
        "vendor/psyz/external/SDL/include",
    ]:
        command.append("-I" + str(project / include))
    command.extend(["-include", str(project / "include/mgs_native.h"), str(source)])
    result = subprocess.run(
        command, check=True, capture_output=True, text=True, encoding="utf-8"
    )
    return result.stdout


def constructor_entries(code: str) -> list[dict]:
    table = re.search(
        r"CHARA\s+_StageCharacterEntries\s*\[\s*\]\s*=\s*\{(.*?)\};", code, re.DOTALL
    )
    if not table:
        raise ValueError("Preprocessed source has no stage constructor table")
    rows = re.findall(r"\{\s*(0x[0-9a-fA-F]+|\d+)\s*,\s*([^{}]+)\}", table[1])
    return [
        {"class_id": int(identity, 0), "function": function.strip()}
        for identity, function in rows
    ]


def original_identities(data: bytes) -> list[int]:
    identities = []
    for offset in range(0, min(len(data), 4096) - 7, 8):
        identity, address = struct.unpack_from("<II", data, offset)
        if not address:
            return identities
        if identity > 65535 or not 0x80010000 <= address < 0x80200000:
            raise ValueError("Invalid original constructor-table entry")
        identities.append(identity)
    raise ValueError("Original constructor table has no terminator")


def compare_archive(path: Path, native: dict) -> dict:
    with path.open("rb") as handle:
        names = stage_table(handle, path.stat().st_size)
    comparisons = []
    resource_only = []
    for stage in names:
        resources = list_assets(path, stage)
        overlays = [entry for entry in resources if entry.identity.endswith(".b")]
        if not overlays:
            resource_only.append(stage)
        if stage not in native:
            continue
        for overlay in overlays:
            with path.open("rb") as handle:
                handle.seek(overlay.offset)
                identities = original_identities(handle.read(overlay.size))
            selected = [row["class_id"] for row in native[stage] if row["class_id"]]
            comparisons.append(
                {
                    "stage": stage,
                    "resource": overlay.identity,
                    "original_entries": len(identities),
                    "native_entries": len(selected),
                    "identities_and_order_match": identities == selected,
                }
            )
    return {
        "archive_name": path.name,
        "stage_count": len(names),
        "unregistered": sorted(set(names) - native.keys()),
        "resource_only": resource_only,
        "tables": comparisons,
    }


def audit(project: Path, clang: Path, discs: list[Path]) -> dict:
    source = project / "vendor/mgs"
    config = json.loads((project / "config/stages.json").read_text(encoding="utf-8"))
    paths, tables = resolve_stages(
        source, project, config["stages"], config["source_overrides"]
    )
    raw_assembly = {}
    for path in paths:
        count = len(
            re.findall(r"#pragma\s+INCLUDE_ASM", path.read_text(encoding="utf-8"))
        )
        if count:
            raw_assembly[path] = count
    selected = set(tables.values()) | raw_assembly.keys()
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
        outputs = list(
            executor.map(lambda path: preprocess(path, project, clang), selected)
        )
    preprocessed = dict(zip(selected, outputs))
    entries = {
        stage: constructor_entries(preprocessed[path]) for stage, path in tables.items()
    }
    nulls = []
    for stage, rows in entries.items():
        for row in rows:
            bare = re.sub(r"\([^)]*\)", "", row["function"])
            if row["class_id"] and not re.search(r"[A-Za-z_]\w*", bare):
                nulls.append({"stage": stage, **row})
    all_tables = {
        path.stem
        for path in (source / "source/stage").glob("*.c")
        if not path.stem.startswith("_")
    }
    return {
        "scope": "Integral main executable; VR excluded; class identities are not function equivalence",
        "configured_stages": config["stages"],
        "unique_constructor_tables": len(set(tables.values())),
        "game_translation_units": len(paths),
        "resident_selection_units": len(source_paths(source, "")),
        "constructor_entries": sum(len(rows) - 1 for rows in entries.values()),
        "unselected_main_tables": sorted(all_tables - set(config["stages"])),
        "nonterminal_null_bindings": nulls,
        "constructors": entries,
        "textual_assembly_files": len(raw_assembly),
        "textual_assembly_pragmas": sum(raw_assembly.values()),
        "active_assembly_sources": [
            path.relative_to(project).as_posix()
            for path in raw_assembly
            if "INCLUDE_ASM" in preprocessed[path]
        ],
        "archives": [compare_archive(path, entries) for path in discs],
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--clang", type=Path, required=True)
    parser.add_argument("--disc", type=Path, action="append", default=[])
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = audit(Path(__file__).resolve().parent.parent, args.clang, args.disc)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                key: value
                for key, value in result.items()
                if key not in {"constructors", "configured_stages", "archives"}
            }
        )
    )


if __name__ == "__main__":
    main()
