"""Versioned, indexed localization packs containing assets from supplied discs."""

import struct
import zlib
from pathlib import Path

MAGIC = b"MGSLOC01"
HEADER = struct.Struct("<8s6I")
ENTRY = struct.Struct("<6I")
DESCRIPTION, FONT, TEXT, VOX, DEMO = range(1, 6)
MAX_RECORDS = 65536
MAX_PAYLOAD = 32 * 1024 * 1024


def text_hash(data: bytes) -> int:
    value = 2166136261
    for byte in data:
        value = ((value ^ byte) * 16777619) & 0xFFFFFFFF
    return value


def write_pack(path: Path, language: int, records: dict) -> None:
    if language not in (1, 2) or not 0 < len(records) <= MAX_RECORDS:
        raise ValueError("Invalid language or record count")
    index = bytearray()
    offset = HEADER.size + ENTRY.size * len(records)
    ordered = sorted(records.items())
    for (kind, disc, identity), payload in ordered:
        if not 0 < len(payload) <= MAX_PAYLOAD:
            raise ValueError(
                f"Invalid localization payload size: {kind}/{disc}/{identity}"
            )
        index.extend(
            ENTRY.pack(kind, disc, identity, offset, len(payload), zlib.crc32(payload))
        )
        offset += len(payload)
    if offset > 1024 * 1024 * 1024:
        raise ValueError("Localization pack exceeds 1 GiB")
    with path.open("xb") as output:
        output.write(
            HEADER.pack(MAGIC, 1, language, len(records), offset, zlib.crc32(index), 0)
        )
        output.write(index)
        for _, payload in ordered:
            output.write(payload)


def add_translation(records: dict, source: bytes, translated: bytes) -> None:
    if source == translated:
        return
    if not source or not translated or b"\0" in source or b"\0" in translated:
        raise ValueError("Translation must contain two nonempty terminated strings")
    key = (TEXT, 0, text_hash(source))
    payload = struct.pack("<I", len(source)) + source + b"\0" + translated + b"\0"
    if key in records and records[key] != payload:
        raise ValueError("Ambiguous translation or text hash collision")
    records[key] = payload
