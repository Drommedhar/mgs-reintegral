"""Inspect Octoshock PSX BK2 input movies; optionally export frame rows as CSV.

Supports two direct DualAnalog/DualShock pads using the BizHawk 1.11.4 schema.
This converts inputs only: it neither runs the native game nor imports save RAM.
Format: https://tasvideos.org/BizHawk/BK2Format
Controller order: BizHawk 1.11.4, Octoshock.CreateControllerDefinition.
"""

import argparse
import csv
import hashlib
import io
import json
import re
import shutil
import tempfile
import zipfile
from collections.abc import Iterable, Iterator
from dataclasses import dataclass
from pathlib import Path
from typing import TextIO

BUTTONS = (
    "Up",
    "Down",
    "Left",
    "Right",
    "Select",
    "Start",
    "Square",
    "Triangle",
    "Circle",
    "Cross",
    "L1",
    "R1",
    "L2",
    "R2",
    "L3",
    "R3",
    "MODE",
)
AXES = ("LStick X", "LStick Y", "RStick X", "RStick Y")
SYSTEM_BUTTONS = ("Open", "Close", "Reset")
DEVICE_NAMES = {2: "DualShock", 3: "DualAnalog"}
SYNC_TYPE = (
    "BizHawk.Emulation.Cores.Sony.PSX.Octoshock+SyncSettings, BizHawk.Emulation.Cores"
)
LOG_KEY = "LogKey:#Disc Select|Open|Close|Reset|" + "".join(
    "#" + "|".join(f"P{port} {name}" for name in (*AXES, *BUTTONS)) + "|"
    for port in (1, 2)
)
CSV_COLUMNS = ("frame", "disc_select", "open", "close", "reset") + tuple(
    f"p{port}_{name.lower().replace(' ', '_')}"
    for port in (1, 2)
    for name in (*AXES, *BUTTONS)
)


@dataclass(frozen=True)
class Pad:
    axes: tuple[int, ...]
    buttons: tuple[bool, ...]


@dataclass(frozen=True)
class Frame:
    index: int
    disc_select: int
    system: tuple[bool, ...]
    pads: tuple[Pad, Pad]

    def csv_row(self) -> list[int]:
        row = [self.index, self.disc_select, *(int(value) for value in self.system)]
        for pad in self.pads:
            row.extend(pad.axes)
            row.extend(int(value) for value in pad.buttons)
        return row


def parse_header(text: str) -> dict[str, str]:
    header = {}
    for line in text.splitlines():
        if not line.strip():
            continue
        name, separator, value = line.partition(" ")
        if not separator or name in header:
            raise ValueError(f"Invalid or duplicate BK2 header field: {name}")
        header[name] = value
    required = {
        "Platform": "PSX",
        "Core": "Octoshock",
        "MovieVersion": "BizHawk v2.0.0",
    }
    for name, expected in required.items():
        if header.get(name) != expected:
            raise ValueError(
                f"Unsupported {name}: expected {expected!r}, got {header.get(name)!r}"
            )
    for name in ("StartsFromSaveRam", "StartsFromSavestate"):
        if header.get(name, "False") not in ("True", "False"):
            raise ValueError(f"Invalid boolean header field: {name}")
    return header


def parse_controllers(text: str) -> tuple[dict, list[dict]]:
    settings = json.loads(text)
    if not isinstance(settings, dict) or set(settings) != {"o"}:
        raise ValueError("Unsupported SyncSettings wrapper; expected an 'o' object")
    core = settings["o"]
    if not isinstance(core, dict) or core.get("$type") != SYNC_TYPE:
        raise ValueError("Unsupported Octoshock SyncSettings type")
    fio = core.get("FIOConfig")
    if not isinstance(fio, dict) or set(fio) != {"Multitaps", "Memcards", "Devices8"}:
        raise ValueError("Unsupported FIOConfig fields")
    if fio["Multitaps"] != [False, False] or any(
        type(x) is not bool for x in fio["Multitaps"]
    ):
        raise ValueError("Multitap controller layouts are not supported")
    cards, devices = fio["Memcards"], fio["Devices8"]
    if (
        not isinstance(cards, list)
        or len(cards) != 2
        or any(type(x) is not bool for x in cards)
    ):
        raise ValueError("Memcards must contain two boolean port settings")
    if (
        not isinstance(devices, list)
        or len(devices) != 8
        or any(type(x) is not int for x in devices)
    ):
        raise ValueError("Devices8 must contain eight integer device identifiers")
    if (
        devices[0] not in DEVICE_NAMES
        or devices[4] not in DEVICE_NAMES
        or any(devices[i] for i in (1, 2, 3, 5, 6, 7))
    ):
        raise ValueError(
            "Only two direct DualAnalog/DualShock controllers are supported"
        )
    controllers = [
        {
            "port": port + 1,
            "device": DEVICE_NAMES[devices[port * 4]],
            "device_id": devices[port * 4],
            "memory_card": cards[port],
            "axes": list(AXES),
            "buttons": list(BUTTONS),
        }
        for port in range(2)
    ]
    return settings, controllers


def parse_integer(token: str, maximum: int, name: str) -> int:
    if re.fullmatch(r" *[0-9]+", token) is None:
        raise ValueError(f"{name} must be a decimal integer")
    value = int(token)
    if not 0 <= value <= maximum:
        raise ValueError(f"{name} is outside 0..{maximum}")
    return value


def parse_buttons(token: str, names: tuple[str, ...]) -> tuple[bool, ...]:
    if len(token) != len(names):
        raise ValueError(
            f"Expected {len(names)} boolean markers for {', '.join(names)}"
        )
    # BK2 treats every marker other than '.' as pressed, regardless of its glyph.
    return tuple(character != "." for character in token)


def parse_frame(line: str, index: int) -> Frame:
    groups = line.split("|")
    if len(groups) != 5 or groups[0] or groups[-1]:
        raise ValueError("Expected system group and exactly two controller groups")
    system = groups[1].split(",")
    if len(system) != 2:
        raise ValueError("Expected Disc Select followed by Open/Close/Reset")
    disc = parse_integer(system[0], 2**31 - 1, "Disc Select")
    events = parse_buttons(system[1], SYSTEM_BUTTONS)
    pads = []
    for port, group in enumerate(groups[2:4], 1):
        values = group.split(",")
        if len(values) != 5:
            raise ValueError(f"P{port} requires four axes and seventeen buttons")
        axes = tuple(
            parse_integer(value, 255, f"P{port} {name}")
            for value, name in zip(values[:4], AXES)
        )
        pads.append(Pad(axes, parse_buttons(values[4], BUTTONS)))
    return Frame(index, disc, events, (pads[0], pads[1]))


def iter_frames(lines: Iterable[str]) -> Iterator[Frame]:
    found_key = False
    count = 0
    for line_number, raw in enumerate(lines, 1):
        line = raw.rstrip("\r\n")
        if not line.strip():
            continue
        if not found_key:
            if line != LOG_KEY:
                raise ValueError(
                    "Unsupported LogKey: expected the complete two-pad Octoshock schema"
                )
            found_key = True
            continue
        try:
            yield parse_frame(line, count)
        except ValueError as error:
            raise ValueError(
                f"Input line {line_number}, frame {count}: {error}"
            ) from error
        count += 1
    if not found_key or count == 0:
        raise ValueError("Input Log contains no frame rows")


def input_lines(handle: TextIO) -> Iterator[str]:
    while line := handle.readline(4097):
        if len(line) > 4096:
            raise ValueError("Input Log line exceeds the supported schema length")
        yield line


def member_info(archive: zipfile.ZipFile, name: str) -> dict:
    if name not in archive.namelist():
        return {"present": False}
    with archive.open(name) as handle:
        digest = hashlib.file_digest(handle, "sha256").hexdigest()
    return {"present": True, "bytes": archive.getinfo(name).file_size, "sha256": digest}


def archive_metadata(archive: zipfile.ZipFile, source: Path) -> dict:
    names = archive.namelist()
    if len(names) != len(set(names)):
        raise ValueError("Archive contains duplicate member names")
    for name, maximum in (
        ("Header.txt", 1024 * 1024),
        ("SyncSettings.json", 1024 * 1024),
        ("Input Log.txt", 512 * 1024 * 1024),
    ):
        if name not in names or archive.getinfo(name).file_size > maximum:
            raise ValueError(f"Missing or oversized required member: {name}")
    header = parse_header(archive.read("Header.txt").decode("utf-8-sig"))
    settings, controllers = parse_controllers(
        archive.read("SyncSettings.json").decode("utf-8-sig")
    )
    ram = member_info(archive, "MovieSaveRam.bin")
    if header.get("StartsFromSaveRam") == "True" and not ram["present"]:
        raise ValueError(
            "Movie declares StartsFromSaveRam but MovieSaveRam.bin is missing"
        )
    with source.open("rb") as handle:
        digest = hashlib.file_digest(handle, "sha256").hexdigest()
    return {
        "format": "mgs-bk2-input-csv-v1",
        "source": str(source),
        "source_sha256": digest,
        "author": header.get("Author", ""),
        "core": header["Core"],
        "emulator": header.get("emuVersion", ""),
        "header": header,
        "sync_settings": settings,
        "controllers": controllers,
        "save_ram": ram,
        "members": [
            {"name": info.filename, "bytes": info.file_size}
            for info in archive.infolist()
        ],
        "clock": "source-emulated-frame",
        "frame_index_base": 0,
        "includes_lag_and_loading_frames": True,
        "native_playback_verified": False,
        "csv_columns": list(CSV_COLUMNS),
    }


def publish_csv(buffer: TextIO, output: Path, metadata: dict) -> None:
    sidecar = output.with_name(output.name + ".metadata.json")
    output.parent.mkdir(parents=True, exist_ok=True)
    created = []
    try:
        with output.open("x", encoding="utf-8", newline="") as target:
            created.append(output)
            with sidecar.open("x", encoding="utf-8", newline="\n") as details:
                created.append(sidecar)
                json.dump(metadata, details, indent=2, ensure_ascii=False)
                details.write("\n")
                buffer.seek(0)
                shutil.copyfileobj(buffer, target)
    except (OSError, ValueError):
        for path in created:
            path.unlink()
        raise


def inspect_movie(
    source: Path, start: int = 0, end: int | None = None, output: Path | None = None
) -> dict:
    if start < 0 or (end is not None and end <= start):
        raise ValueError("Frame range must satisfy 0 <= start < end (end is exclusive)")
    with (
        zipfile.ZipFile(source) as archive,
        tempfile.TemporaryFile(mode="w+", encoding="utf-8", newline="") as buffer,
    ):
        metadata = archive_metadata(archive, source)
        writer = csv.writer(buffer)
        if output is not None:
            writer.writerow(CSV_COLUMNS)
        count = selected = 0
        with (
            archive.open("Input Log.txt") as raw,
            io.TextIOWrapper(raw, encoding="utf-8-sig", newline=None) as text,
        ):
            for frame in iter_frames(input_lines(text)):
                count += 1
                if frame.index >= start and (end is None or frame.index < end):
                    selected += 1
                    if output is not None:
                        writer.writerow(frame.csv_row())
        if start >= count or (end is not None and end > count):
            raise ValueError(f"Requested frame range exceeds movie length {count}")
        metadata.update(
            {
                "frames": count,
                "slice_start": start,
                "slice_end_exclusive": end if end is not None else count,
                "slice_frames": selected,
            }
        )
        if output is not None:
            publish_csv(buffer, output, metadata)
        return metadata


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="PSX Octoshock .bk2 archive")
    parser.add_argument(
        "--start-frame", type=int, default=0, help="Zero-based inclusive source frame"
    )
    parser.add_argument(
        "--end-frame", type=int, help="Exclusive source frame; defaults to movie end"
    )
    parser.add_argument(
        "--output",
        type=Path,
        help="New CSV path; also creates .metadata.json with attribution and hashes",
    )
    args = parser.parse_args()
    try:
        metadata = inspect_movie(
            args.source, args.start_frame, args.end_frame, args.output
        )
    except (OSError, ValueError, zipfile.BadZipFile, RuntimeError) as error:
        parser.exit(1, f"BK2 inspection failed: {error}\n")
    print(json.dumps(metadata, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
