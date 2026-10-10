"""List or export Integral STAGE.DIR resources for exact-size loose overrides.

Layouts follow FoxdieTeam mgs_reversing f54dbb2a58adfc2755403296c9ebb653fbec277b:
source/libfs/{datacnf.h,cdstage.c}; stage directory layout also follows
David Montero's published port/extract_disc.py at 5a2c7ee2.
"""

import argparse
import hashlib
import json
import re
import struct
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import BinaryIO

BLOCK_BYTES = 2048
MOD_RESOURCE_LIMIT = 16 * 1024 * 1024


@dataclass(frozen=True)
class Asset:
    stage: str
    identity: str
    region: str
    offset: int
    size: int
    overridable: bool


def read_at(handle: BinaryIO, offset: int, size: int, file_size: int) -> bytes:
    if min(offset, size) < 0 or offset + size > file_size:
        raise ValueError("Stage resource extent is outside STAGE.DIR")
    handle.seek(offset)
    data = handle.read(size)
    if len(data) != size:
        raise ValueError("Truncated stage resource")
    return data


def stage_table(handle: BinaryIO, file_size: int) -> dict[str, int]:
    header = read_at(handle, 0, BLOCK_BYTES, file_size)
    table_size = struct.unpack_from("<I", header)[0]
    if table_size > BLOCK_BYTES - 4 or table_size % 12:
        raise ValueError("Invalid STAGE.DIR table size")
    stages = {}
    for offset in range(4, 4 + table_size, 12):
        raw_name, sector = struct.unpack_from("<8sI", header, offset)
        name = raw_name.rstrip(b"\0").decode("ascii")
        if re.fullmatch(r"[a-z0-9_]{1,8}", name) is None or name in stages:
            raise ValueError("Invalid or duplicate stage name")
        if sector == 0 or sector * BLOCK_BYTES >= file_size:
            raise ValueError(f"Stage {name} is outside STAGE.DIR")
        stages[name] = sector * BLOCK_BYTES
    return stages


def stage_tags(handle: BinaryIO, start: int, file_size: int) -> tuple[list, int, int]:
    first = read_at(handle, start, 4, file_size)
    header_sectors, _, total_sectors = struct.unpack("<BBH", first)
    if not 0 < header_sectors <= total_sectors:
        raise ValueError("Invalid stage header/total sector count")
    end = start + total_sectors * BLOCK_BYTES
    header = read_at(handle, start, header_sectors * BLOCK_BYTES, file_size)
    if end > file_size:
        raise ValueError("Declared stage size exceeds STAGE.DIR")
    tags = []
    for offset in range(4, len(header) - 7, 8):
        tag = struct.unpack_from("<HBBI", header, offset)
        if tag[1] == 0:
            return tags, start + len(header), end
        tags.append(tag)
    raise ValueError("Stage configuration has no terminator")


def asset(
    stage: str, identifier: int, extension: int, region: int, offset: int, size: int
) -> Asset:
    if not ord("a") <= extension <= ord("z"):
        raise ValueError("Unsupported resource extension in stage data")
    return Asset(
        stage,
        f"{identifier:04x}.{chr(extension)}",
        chr(region),
        offset,
        size,
        region in b"cnr" and extension != ord("b") and 0 < size <= MOD_RESOURCE_LIMIT,
    )


def cached_assets(
    stage: str, tags: list, index: int, cursor: int
) -> tuple[list[Asset], int, int]:
    resources = []
    while index < len(tags):
        identifier, region, extension, offset = tags[index]
        if region != ord("c"):
            raise ValueError("Cache section has no size terminator")
        if extension == 0xFF:
            return resources, index + 1, offset
        if index + 1 == len(tags) or tags[index + 1][3] <= offset:
            raise ValueError("Cache resource offsets are not increasing")
        length = tags[index + 1][3] - offset
        resources.append(
            asset(stage, identifier, extension, region, cursor + offset, length)
        )
        index += 1
    raise ValueError("Cache section has no terminator")


def archive_assets(
    handle: BinaryIO, stage: str, cursor: int, size: int, region: int, end: int
) -> list[Asset]:
    resources = []
    stop = cursor + size
    if stop > end:
        raise ValueError("DAR section exceeds its stage")
    while cursor < stop:
        identifier, extension, length = struct.unpack(
            "<HHI", read_at(handle, cursor, 8, stop)
        )
        cursor += 8
        if length == 0 or cursor + length > stop:
            raise ValueError("Invalid DAR resource size")
        resources.append(asset(stage, identifier, extension, region, cursor, length))
        cursor += length
    return resources


def list_assets(path: Path, stage: str) -> list[Asset]:
    with path.open("rb") as handle:
        file_size = path.stat().st_size
        table = stage_table(handle, file_size)
        if stage not in table:
            raise ValueError(f"Unknown stage: {stage}; available: {', '.join(table)}")
        tags, cursor, end = stage_tags(handle, table[stage], file_size)
        resources = []
        index = 0
        while index < len(tags):
            identifier, region, extension, size = tags[index]
            if region == ord("c"):
                group, index, size = cached_assets(stage, tags, index, cursor)
                resources.extend(group)
            else:
                index += 1
                if region in b"nr":
                    resources.extend(
                        archive_assets(handle, stage, cursor, size, region, end)
                    )
                elif region == ord("s"):
                    resources.append(
                        asset(stage, identifier, extension, region, cursor, size)
                    )
                else:
                    raise ValueError(f"Unsupported stage storage region: {region}")
            cursor += ((size + BLOCK_BYTES - 1) // BLOCK_BYTES) * BLOCK_BYTES
            if cursor > end:
                raise ValueError("Resource section exceeds its declared stage")
        if cursor != end:
            raise ValueError("Stage resources do not consume the declared stage")
    return resources


def export_asset(
    path: Path, resources: list[Asset], identity: str, output: Path
) -> dict:
    matches = [entry for entry in resources if entry.identity == identity]
    if not matches or any(not entry.overridable for entry in matches):
        raise ValueError("Resource is absent or not supported for loose overrides")
    payloads = []
    with path.open("rb") as handle:
        for entry in matches:
            payloads.append(
                read_at(handle, entry.offset, entry.size, path.stat().st_size)
            )
    if any(payload != payloads[0] for payload in payloads[1:]):
        raise ValueError(
            "Resource identity has conflicting occurrences; export is ambiguous"
        )
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("xb") as handle:
        handle.write(payloads[0])
    return {
        "identity": identity,
        "size": len(payloads[0]),
        "sha256": hashlib.sha256(payloads[0]).hexdigest(),
        "output": str(output),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stage-dir", type=Path, required=True)
    parser.add_argument("--stage", required=True)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--export", dest="identity")
    parser.add_argument("--output", type=Path)
    arguments = parser.parse_args()
    if bool(arguments.identity) != bool(arguments.output):
        parser.error("--export and --output are required together")
    try:
        resources = list_assets(arguments.stage_dir, arguments.stage)
        if arguments.identity:
            print(
                json.dumps(
                    export_asset(
                        arguments.stage_dir,
                        resources,
                        arguments.identity,
                        arguments.output,
                    ),
                    indent=2,
                )
            )
        elif arguments.json:
            print(json.dumps([asdict(entry) for entry in resources], indent=2))
        else:
            print("Identity   Bytes       Region  Override")
            for entry in resources:
                print(
                    f"{entry.identity:8}   {entry.size:9}   {entry.region}       {entry.overridable}"
                )
    except (OSError, ValueError) as error:
        parser.exit(1, f"Resource inspection failed: {error}\n")


if __name__ == "__main__":
    main()
