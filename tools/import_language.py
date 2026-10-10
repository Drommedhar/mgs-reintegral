"""Import optional localization resources from a supported, user-supplied disc pair."""

import argparse
import hashlib
import json
import re
import sys
import tempfile
from collections import defaultdict
from contextlib import contextmanager
from pathlib import Path

from import_content import Disc, catalogue, cue_image, file_hash
from language_assets import PROFILES, ui_records
from language_mapping import compile_disc, compile_text
from language_pack import write_pack
from list_assets import list_assets

INTEGRAL_SHA256 = "4b8252b65953a02021486406cfcdca1c7670d1d1a8f3cf6e750ef6e360dc3a2f"


@contextmanager
def open_disc(path: Path, serial: str):
    image = cue_image(path) if path.suffix.lower() == ".cue" else path
    if image.suffix.lower() != ".bin" or image.is_symlink() or not image.is_file():
        raise ValueError("Select a regular BIN image or its single-track CUE")
    with image.open("rb") as handle:
        disc = Disc(handle, image.stat().st_size)
        files = {entry.path: entry for entry in catalogue(disc)}
        system = files.get("SYSTEM.CNF")
        if system is None:
            raise ValueError("Donor disc has no SYSTEM.CNF")
        config = disc.read_metadata(system.lba, system.size).decode("ascii")
        boot = re.findall(r"(?im)^BOOT\s*=\s*cdrom:\\([^;\r\n]+);1\s*$", config)
        if len(boot) != 1 or boot[0].split("\\")[-1].upper() != serial:
            raise ValueError(f"Expected donor disc {serial}")
        yield disc, files, image


def read_file(disc: Disc, files: dict, name: str, limit: int) -> bytes:
    entry = files.get(name)
    if entry is None or not 0 < entry.size <= limit:
        raise ValueError(f"Missing or oversized donor resource: {name}")
    return b"".join(
        disc.sector(entry.lba + i) for i in range(disc.extent(entry.lba, entry.size))
    )[: entry.size]


def read_font(stage: Path) -> bytes:
    matches = [
        asset for asset in list_assets(stage, "init") if asset.identity == "ca68.r"
    ]
    if len(matches) != 1:
        raise ValueError("Donor init stage has no unique font resource")
    asset = matches[0]
    with stage.open("rb") as handle:
        handle.seek(asset.offset)
        return handle.read(asset.size)


def resources(disc, files, directory):
    directory.mkdir()
    stage = directory / "STAGE.DIR"
    stage.write_bytes(read_file(disc, files, "MGS/STAGE.DIR", 128 * 1024 * 1024))
    return {
        "STAGE.DIR": stage,
        **{
            name: read_file(disc, files, "MGS/" + name, 512 * 1024 * 1024)
            for name in ("RADIO.DAT", "VOX.DAT", "DEMO.DAT")
        },
    }


def read_base(path, number, temporary):
    serial = "SLPM_862.47" if number == 0 else "SLPM_862.48"
    with open_disc(path, serial) as (disc, files, image):
        executable = read_file(disc, files, "MGS/" + serial, 1024 * 1024)
        if hashlib.sha256(executable).hexdigest() != INTEGRAL_SHA256:
            raise ValueError("Unsupported Integral base executable revision")
        return resources(disc, files, temporary / f"base{number}"), file_hash(image)


def import_pair(
    language: str, images: list[Path], bases: list[Path], destination: Path
) -> dict:
    profile = PROFILES[language]
    if destination.suffix.lower() != ".mgslang":
        raise ValueError("Destination must use the .mgslang extension")
    if (
        destination.exists()
        or destination.with_suffix(".json").exists()
        or destination.is_symlink()
    ):
        raise ValueError(
            "Language pack or receipt already exists; choose a new destination"
        )
    destination.parent.mkdir(parents=True, exist_ok=True)
    receipts = []
    records = {}
    translations = defaultdict(set)
    coverage = []
    with tempfile.TemporaryDirectory(prefix="mgs-language-") as temporary:
        for number, path in enumerate(images):
            print(
                f"Disc {number + 1}/2: reading and checking regional resources…",
                flush=True,
            )
            with open_disc(path, profile["serials"][number]) as (disc, files, image):
                executable = read_file(
                    disc, files, profile["executables"][number], 1024 * 1024
                )
                digest = hashlib.sha256(executable).hexdigest()
                if digest != profile["sha256"]:
                    raise ValueError("Unsupported donor executable revision")
                donor = resources(disc, files, Path(temporary) / f"donor{number}")
                if number == 0:
                    records = ui_records(
                        executable, read_font(donor["STAGE.DIR"]), language
                    )
                receipts.append(
                    {
                        "serial": profile["serials"][number],
                        "image": str(image.resolve()),
                        "imageSha256": file_hash(image),
                        "executableSha256": digest,
                    }
                )
            print(
                f"Disc {number + 1}/2: reading and checking Integral resources…",
                flush=True,
            )
            base, base_hash = read_base(bases[number], number, Path(temporary))
            receipts[-1]["baseImageSha256"] = base_hash
            print(f"Disc {number + 1}/2: matching text and speech…", flush=True)
            disc_coverage, candidates = compile_disc(
                records, number + 1, language, base, donor
            )
            coverage.append(disc_coverage)
            for source, targets in candidates.items():
                translations[source].update(targets)
            del base, donor
        text_coverage = compile_text(records, translations)
        print("Writing language pack…", flush=True)
        write_pack(destination, profile["language"], records)
    print("Verifying pack hash and writing coverage receipt…", flush=True)
    receipt = {
        "format": "mgs-language.v1",
        "language": language,
        "sources": receipts,
        "packSha256": file_hash(destination),
        "records": len(records),
        "mappingVersion": 1,
        "baseEdition": "Integral SLPM_862.47/48",
        "coverage": {
            "inventoryDescriptions": 37,
            "text": text_coverage,
            "discs": coverage,
            "movies": False,
        },
    }
    with destination.with_suffix(".json").open("x", encoding="utf-8") as handle:
        json.dump(receipt, handle, indent=2)
        handle.write("\n")
    return receipt


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)
    sys.stderr.reconfigure(encoding="utf-8", line_buffering=True)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--language", choices=PROFILES, required=True)
    parser.add_argument("--disc-one", type=Path, required=True)
    parser.add_argument("--disc-two", type=Path, required=True)
    parser.add_argument("--base-one", type=Path, required=True)
    parser.add_argument("--base-two", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        receipt = import_pair(
            args.language,
            [args.disc_one, args.disc_two],
            [args.base_one, args.base_two],
            args.output,
        )
    except (OSError, ValueError) as error:
        parser.exit(2, f"Language import failed: {error}\n")
    print(f"Imported {receipt['records']} records to {args.output}")
    for number, disc in enumerate(receipt["coverage"]["discs"], 1):
        print(
            f"Disc {number}: "
            + ", ".join(
                f"{kind} {value['mapped']}/{value['total']}"
                for kind, value in disc["streams"].items()
            )
        )
    print(f"Coverage and source hashes: {args.output.with_suffix('.json')}")


if __name__ == "__main__":
    main()
