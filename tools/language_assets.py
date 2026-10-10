"""Regional executable tables and font data; offsets are pinned by executable hash."""

import hashlib
import struct

from language_pack import DESCRIPTION, FONT

PROFILES = {
    "en": {
        "language": 1,
        "serials": ("SLUS_005.94", "SLUS_007.76"),
        "executables": ("MGS/SLUS_005.94", "MGS/SLUS_007.76"),
        "sha256": "3342f75717c5134aec832547691c2354e67a253abfcfa9e0e823e2133bb1fc32",
        "items": 0x91330,
        "weapons": 0x9151C,
    },
    "de": {
        "language": 2,
        "serials": ("SLES_015.07", "SLES_115.07"),
        "executables": ("MGS/MGS1.EXE", "MGS/MGS2.EXE"),
        "sha256": "324f05cf342afe21bf861c0d213f30b523ace0da4bee8022d4bf185e20d8044d",
        "items": 0x9001C,
        "weapons": 0x90210,
    },
}


def cstring(data: bytes, offset: int, limit: int = 4096) -> bytes:
    if not 0 <= offset < len(data):
        raise ValueError("String offset is outside its resource")
    end = data.find(b"\0", offset, min(len(data), offset + limit))
    if end < 0:
        raise ValueError("Unterminated localized string")
    return data[offset:end]


def regional_text(data: bytes, language: str) -> bytes:
    result = bytearray()
    offset = 0
    while offset < len(data):
        byte = data[offset]
        if byte == 0x1F and language == "de":
            if offset + 1 == len(data) or not 1 <= data[offset + 1] <= 127:
                raise ValueError("Invalid German extended glyph")
            result.extend((0x80, 127 + data[offset + 1]))
            offset += 2
        elif byte >= 0x80:
            if offset + 1 == len(data):
                raise ValueError("Truncated two-byte character")
            result.extend(data[offset : offset + 2])
            offset += 2
        else:
            result.append(byte)
            offset += 1
    return bytes(result)


def pointer_strings(executable: bytes, offset: int, count: int) -> list[bytes]:
    base = struct.unpack_from("<I", executable, 0x18)[0]
    pointers = struct.unpack_from(f"<{count}I", executable, offset)
    return [cstring(executable, pointer - base + 2048) for pointer in pointers]


def ui_records(executable: bytes, font: bytes, language: str) -> dict:
    profile = PROFILES[language]
    if hashlib.sha256(executable).hexdigest() != profile["sha256"]:
        raise ValueError("Unsupported donor executable revision")
    records = {(FONT, 0, 0): font}
    items = pointer_strings(executable, profile["items"], 26)
    card = items[17]
    marker = b"1" if language == "en" else b"?"
    if card.count(marker) != 1:
        raise ValueError("Donor card description no longer has a unique level field")
    items[17] = card.replace(marker, b"\x1e")
    items.append(cstring(executable, profile["items"] + 26 * 4))
    weapons = pointer_strings(executable, profile["weapons"], 10)
    for first, strings in ((0, items), (100, weapons)):
        for index, text in enumerate(strings):
            records[(DESCRIPTION, 0, first + index)] = (
                regional_text(text, language) + b"\0"
            )
    return records
