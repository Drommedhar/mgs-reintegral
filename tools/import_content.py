"""Import user-owned Integral discs; never modify or distribute disc contents.

ISO9660/raw-sector layout follows David Montero's published extractor:
https://github.com/davidmonterocrespo24/mgs_reversing/blob/
5a2c7ee2be477bdde465654b5bf52de1275e1096/port/extract_disc.py
Bounds, identities, streaming, output isolation and receipts are enforced here.
"""

import argparse
import hashlib
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import BinaryIO

SECTOR_BYTES = 2352
BLOCK_BYTES = 2048
SYNC = b"\x00" + b"\xff" * 10 + b"\x00"
EXTRACTOR_REVISION = "5a2c7ee2be477bdde465654b5bf52de1275e1096"
IDENTITY_REVISION = "f54dbb2a58adfc2755403296c9ebb653fbec277b"
GAME_HASH = "4b8252b65953a02021486406cfcdca1c7670d1d1a8f3cf6e750ef6e360dc3a2f"
VR_HASH = "c370f8e41ec8fb78238bfe2ddbfc25a6d37ec8f0972c86ebfde075ecd4ee8dca"
EDITIONS = {
    "SLPM_862.47": ("disc1", GAME_HASH),
    "SLPM_862.48": ("disc2", GAME_HASH),
    "SLPM_862.49": ("disc3", VR_HASH),
}


@dataclass(frozen=True)
class Entry:
    path: str
    lba: int
    size: int
    directory: bool


@dataclass(frozen=True)
class DiscPlan:
    cue: Path
    image: Path
    serial: str
    files: tuple[Entry, ...]


def both_endian(data: bytes, offset: int, width: int) -> int:
    little = int.from_bytes(data[offset : offset + width], "little")
    big = int.from_bytes(data[offset + width : offset + 2 * width], "big")
    if little != big:
        raise ValueError("ISO9660 endian copies disagree")
    return little


def cue_image(cue: Path) -> Path:
    lines = [line.strip() for line in cue.read_text(encoding="utf-8-sig").splitlines()]
    lines = [line for line in lines if line and not line.startswith("REM ")]
    if len(lines) != 3 or lines[1:] != ["TRACK 01 MODE2/2352", "INDEX 01 00:00:00"]:
        raise ValueError(f"Unsupported CUE layout: {cue.name}")
    match = re.fullmatch(r'FILE "([^"/\\]+)" BINARY', lines[0])
    if match is None:
        raise ValueError(f"CUE must name one local BIN file: {cue.name}")
    image = cue.parent / match[1]
    if image.suffix.lower() != ".bin" or image.is_symlink() or not image.is_file():
        raise ValueError(f"CUE image is not a regular BIN file: {image}")
    if image.resolve().parent != cue.parent.resolve():
        raise ValueError("CUE image escapes its source directory")
    return image


class Disc:
    def __init__(self, handle: BinaryIO, size: int):
        if size % SECTOR_BYTES or size < 17 * SECTOR_BYTES:
            raise ValueError("BIN length is not a complete raw-sector image")
        self.handle = handle
        self.sectors = size // SECTOR_BYTES

    def extent(self, lba: int, size: int) -> int:
        count = (size + BLOCK_BYTES - 1) // BLOCK_BYTES
        if lba < 0 or size < 0 or lba + count > self.sectors:
            raise ValueError(
                f"Disc extent is outside the image: LBA {lba}, bytes {size}"
            )
        return count

    def raw_sector(self, lba: int) -> bytes:
        self.extent(lba, BLOCK_BYTES)
        self.handle.seek(lba * SECTOR_BYTES)
        raw = self.handle.read(SECTOR_BYTES)
        if len(raw) != SECTOR_BYTES or raw[:12] != SYNC or raw[15] != 2:
            raise ValueError(f"Invalid MODE2 sector at LBA {lba}")
        if raw[16:20] != raw[20:24]:
            raise ValueError(f"XA subheader copies disagree at LBA {lba}")
        return raw

    def sector(self, lba: int) -> bytes:
        raw = self.raw_sector(lba)
        if raw[18] & 0x20:
            raise ValueError(f"ISO metadata cannot use a Form2 sector: LBA {lba}")
        return raw[24 : 24 + BLOCK_BYTES]

    def read_metadata(self, lba: int, size: int) -> bytes:
        count = self.extent(lba, size)
        if size > 4 * 1024 * 1024:
            raise ValueError("ISO directory/identity metadata exceeds the size limit")
        return b"".join(self.sector(lba + index) for index in range(count))[:size]

    def root(self) -> Entry:
        pvd = self.sector(16)
        if pvd[:7] != b"\x01CD001\x01":
            raise ValueError("Expected ISO9660 primary volume descriptor at LBA 16")
        if both_endian(pvd, 128, 2) != BLOCK_BYTES:
            raise ValueError("Unsupported ISO logical block size")
        if both_endian(pvd, 80, 4) > self.sectors:
            raise ValueError("ISO volume exceeds the raw image")
        root = directory_record(pvd[156:190], "")
        if not root.directory:
            raise ValueError("ISO root is not a directory")
        return root

    def children(self, entry: Entry) -> list[Entry]:
        data = self.read_metadata(entry.lba, entry.size)
        children = []
        offset = 0
        while offset < len(data):
            length = data[offset]
            if length == 0:
                offset = (offset // BLOCK_BYTES + 1) * BLOCK_BYTES
                continue
            if (
                offset + length > len(data)
                or offset % BLOCK_BYTES + length > BLOCK_BYTES
            ):
                raise ValueError("Truncated or cross-sector ISO directory record")
            record = data[offset : offset + length]
            offset += length
            child = directory_record(record, entry.path)
            if child.path:
                self.extent(child.lba, child.size)
                children.append(child)
        return children


def directory_record(record: bytes, parent: str) -> Entry:
    if len(record) < 34 or record[0] != len(record) or 33 + record[32] > len(record):
        raise ValueError("Invalid ISO directory record length")
    if record[1] or record[25] & ~3 or record[26] or record[27]:
        raise ValueError(
            "Extended, multi-extent or interleaved ISO entries are unsupported"
        )
    if both_endian(record, 28, 2) != 1:
        raise ValueError("Multi-volume ISO entries are unsupported")
    name = record[33 : 33 + record[32]]
    if name in (b"\x00", b"\x01"):
        path = ""
    else:
        text = name.decode("ascii")
        text = text.removesuffix(";1")
        if re.fullmatch(r"[A-Z0-9_][A-Z0-9_.-]*", text) is None or text.endswith("."):
            raise ValueError(f"Unsafe or unsupported ISO filename: {text!r}")
        if text.split(".", 1)[0] in {"CON", "PRN", "AUX", "NUL"} or re.match(
            r"(?:COM|LPT)[1-9](?:\.|$)", text
        ):
            raise ValueError(f"Reserved Windows filename: {text}")
        path = f"{parent}/{text}" if parent else text
    return Entry(
        path,
        both_endian(record, 2, 4),
        both_endian(record, 10, 4),
        bool(record[25] & 2),
    )


def catalogue(disc: Disc) -> tuple[Entry, ...]:
    pending = [disc.root()]
    directories = set()
    paths = set()
    files = []
    while pending:
        directory = pending.pop()
        if directory.lba in directories or len(directories) >= 1024:
            raise ValueError("Cyclic, aliased or excessive ISO directory tree")
        directories.add(directory.lba)
        for entry in disc.children(directory):
            if entry.path.casefold() in paths:
                raise ValueError(f"Duplicate ISO path: {entry.path}")
            paths.add(entry.path.casefold())
            if entry.directory:
                pending.append(entry)
            else:
                files.append(entry)
    return tuple(sorted(files, key=lambda entry: entry.path))


def identify(disc: Disc, files: tuple[Entry, ...]) -> str:
    system = next((entry for entry in files if entry.path == "SYSTEM.CNF"), None)
    if system is None:
        raise ValueError("Disc has no SYSTEM.CNF")
    config = disc.read_metadata(system.lba, system.size).decode("ascii")
    boot = re.findall(
        r"(?im)^BOOT\s*=\s*cdrom:\\MGS\\(SLPM_862\.[0-9]{2});1\s*$", config
    )
    if len(boot) != 1 or boot[0] not in EDITIONS:
        raise ValueError("SYSTEM.CNF does not identify a supported Integral executable")
    serial = boot[0]
    executable = next((entry for entry in files if entry.path == f"MGS/{serial}"), None)
    if executable is None:
        raise ValueError(f"Missing boot executable {serial}")
    data = disc.read_metadata(executable.lba, executable.size)
    if (
        not data.startswith(b"PS-X EXE")
        or hashlib.sha256(data).hexdigest() != EDITIONS[serial][1]
    ):
        raise ValueError(
            f"Executable checksum does not match FoxdieTeam's {serial} reference"
        )
    if not any(entry.path == "MGS/STAGE.DIR" for entry in files):
        raise ValueError("Disc has no MGS/STAGE.DIR")
    return serial


def plan_import(source: Path, cues: list[Path] | None = None) -> list[DiscPlan]:
    if cues is None:
        cues = sorted(
            path for path in source.iterdir() if path.suffix.lower() == ".cue"
        )
    if len(cues) not in (2, 3):
        raise ValueError(
            "Select Integral discs 1 and 2, optionally VR; use --cue when the folder contains other editions"
        )
    plans = []
    serials = set()
    for cue in cues:
        if cue.resolve().parent != source.resolve():
            raise ValueError("Selected CUE files must be inside the source directory")
        if cue.is_symlink() or not cue.is_file():
            raise ValueError(f"CUE is not a regular file: {cue}")
        image = cue_image(cue)
        with image.open("rb") as handle:
            disc = Disc(handle, image.stat().st_size)
            files = catalogue(disc)
            serial = identify(disc, files)
        if serial in serials:
            raise ValueError(f"Duplicate disc identity: {serial}")
        serials.add(serial)
        plans.append(DiscPlan(cue, image, serial, files))
    if not {"SLPM_862.47", "SLPM_862.48"}.issubset(serials):
        raise ValueError("Both Integral campaign discs 1 and 2 are required")
    return sorted(plans, key=lambda plan: plan.serial)


def file_hash(path: Path) -> str:
    with path.open("rb") as handle:
        return hashlib.file_digest(handle, "sha256").hexdigest()


def write_raw_extent(disc: Disc, entry: Entry, path: Path) -> str:
    path.parent.mkdir(parents=True, exist_ok=True)
    digest = hashlib.sha256()
    with path.open("xb") as output:
        for index in range(disc.extent(entry.lba, entry.size)):
            raw = disc.raw_sector(entry.lba + index)
            output.write(raw)
            digest.update(raw)
    return digest.hexdigest()


def extract_file(disc: Disc, entry: Entry, output: Path) -> dict:
    destination = output / entry.path
    destination.parent.mkdir(parents=True, exist_ok=True)
    digest = hashlib.sha256()
    form2 = 0
    remaining = entry.size
    with destination.open("xb") as handle:
        for index in range(disc.extent(entry.lba, entry.size)):
            raw = disc.raw_sector(entry.lba + index)
            form2 += bool(raw[18] & 0x20)
            payload = raw[24 : 24 + min(BLOCK_BYTES, remaining)]
            handle.write(payload)
            digest.update(payload)
            remaining -= len(payload)
    receipt = {
        "path": entry.path,
        "lba": entry.lba,
        "size": entry.size,
        "sha256": digest.hexdigest(),
        "form2Sectors": form2,
        "representation": "ISO9660 logical 2048-byte blocks",
    }
    if form2:
        raw_path = Path(".raw-sectors") / entry.path
        receipt["rawSectors"] = {
            "path": raw_path.as_posix(),
            "sectorBytes": SECTOR_BYTES,
            "sha256": write_raw_extent(disc, entry, output / raw_path),
        }
    return receipt


def write_json(path: Path, document: dict) -> None:
    with path.open("x", encoding="utf-8", newline="\n") as handle:
        json.dump(document, handle, indent=2)
        handle.write("\n")


def extract_disc(plan: DiscPlan, output: Path) -> dict:
    name = EDITIONS[plan.serial][0]
    destination = output / name
    destination.mkdir()
    receipts = []
    omitted = []
    with plan.image.open("rb") as handle:
        disc = Disc(handle, plan.image.stat().st_size)
        for entry in plan.files:
            if entry.path == "DUMMY3M.DAT":
                omitted.append(
                    {
                        "path": entry.path,
                        "lba": entry.lba,
                        "size": entry.size,
                        "reason": "Disc padding; not a runtime resource",
                    }
                )
                continue
            receipts.append(extract_file(disc, entry, destination))
    receipt = {
        "format": "mgs-integral.disc.v1",
        "serial": plan.serial,
        "image": {
            "path": str(plan.image),
            "size": plan.image.stat().st_size,
            "sha256": file_hash(plan.image),
        },
        "cue": {"path": str(plan.cue), "sha256": file_hash(plan.cue)},
        "files": receipts,
        "omitted": omitted,
    }
    write_json(destination / "manifest.json", receipt)
    return {
        "disc": name,
        "serial": plan.serial,
        "manifest": f"{name}/manifest.json",
        "files": len(receipts),
        "imageSha256": receipt["image"]["sha256"],
    }


def import_content(source: Path, output: Path, cues: list[Path] | None = None) -> dict:
    source = source.resolve(strict=True)
    output = output.resolve()
    if not source.is_dir():
        raise ValueError(
            "Source must be a directory containing the Integral BIN/CUE pairs"
        )
    if output.is_relative_to(source) or source.is_relative_to(output):
        raise ValueError("Output must be separate from the source directory")
    if output.exists():
        raise FileExistsError(f"Refusing existing output: {output}")
    plans = plan_import(source, cues)
    output.mkdir(parents=True, exist_ok=False)
    write_json(
        output / "incomplete.json", {"status": "incomplete", "source": str(source)}
    )
    discs = []
    for plan in plans:
        print(f"Importing {plan.serial} as {EDITIONS[plan.serial][0]}", flush=True)
        discs.append(extract_disc(plan, output))
    manifest = {
        "format": "mgs-integral.content.v1",
        "complete": True,
        "discs": discs,
        "extractorReference": f"davidmonterocrespo24/mgs_reversing@{EXTRACTOR_REVISION}",
        "identityReference": f"FoxdieTeam/mgs_reversing@{IDENTITY_REVISION}",
        "streamPolicy": "Form2 files also retain full 2352-byte sector copies; logical files alone are not lossless XA streams.",
    }
    write_json(output / "manifest.json", manifest)
    (output / "incomplete.json").unlink()
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument(
        "--cue",
        nargs="+",
        type=Path,
        help="Explicit campaign CUE files; VR is optional",
    )
    options = parser.parse_args()
    try:
        result = import_content(options.source, options.output, options.cue)
    except (OSError, ValueError) as error:
        parser.exit(
            1,
            f"Import failed: {error}\nIncomplete outputs are retained and cannot be overwritten.\n",
        )
    print(f"Imported {len(result['discs'])} discs into {options.output}")


if __name__ == "__main__":
    main()
