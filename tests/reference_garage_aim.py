"""Execute the retail garage gun rotation and derive composed bullet fixtures."""

import argparse
import hashlib
import itertools
import struct
from pathlib import Path

from unicorn import UC_ARCH_MIPS, UC_MODE_LITTLE_ENDIAN, UC_MODE_MIPS32, Uc
from unicorn.mips_const import (
    UC_MIPS_REG_A0,
    UC_MIPS_REG_A1,
    UC_MIPS_REG_PC,
    UC_MIPS_REG_RA,
    UC_MIPS_REG_SP,
)

ENTRY, SIZE, STOP = 0x800DF2F8, 652, 0x801FF800
INPUT, OUTPUT = 0x80180000, 0x80180100
PITCHES = (19, -32768, -300, -19, 0, 80, 200, 300, 2048, 32767)
YAWS = (764, -32768, -4096, -1024, -1, 0, 256, 1024, 1499, 2048, 3072, 4095, 32767)
ROLLS = (0, -512, 512, 1024)
ROOTS = (
    ((0, 0, 0), (0, 0, 0)),
    ((0, 1499, 0), (612, 0, 439)),
    ((120, 2048, -100), (-3100, -250, 2700)),
)


def clamp_short(value: int) -> int:
    return min(32767, max(-32768, value))


def multiply(left: tuple[int, ...], right: tuple[int, ...]) -> tuple[int, ...]:
    return tuple(
        clamp_short(sum(left[row * 3 + k] * right[k * 3 + col] for k in range(3)) >> 12)
        for row in range(3)
        for col in range(3)
    )


def transform(
    matrix: tuple[int, ...],
    vector: tuple[int, ...],
    translation: tuple[int, ...] = (0, 0, 0),
) -> tuple[int, ...]:
    return tuple(
        (sum(matrix[row * 3 + k] * vector[k] for k in range(3)) >> 12)
        + translation[row]
        for row in range(3)
    )


def geometry_hash(
    aim: tuple[int, ...], root: tuple[int, ...], translation: tuple[int, ...]
) -> int:
    gun = multiply(root, aim)
    origin = transform(root, (0, 1435, -925), translation)
    bullet = multiply(gun, (4096, 0, 0, 0, 0, 4096, 0, -4096, 0))
    muzzle = transform(gun, (0, 286, 574), origin)
    step = tuple(clamp_short(value) for value in transform(bullet, (0, -750, 0)))
    start = tuple(
        clamp_short(value) for value in transform(bullet, (0, 400, 0), muzzle)
    )
    data = struct.pack("<9h3i9h3i6h", *gun, *origin, *bullet, *muzzle, *step, *start)
    result = 2166136261
    for byte in data:
        result = ((result ^ byte) * 16777619) & 0xFFFFFFFF
    return result


class RotationReference:
    def __init__(self, image: bytes):
        if image[:8] != b"PS-X EXE":
            raise ValueError("Expected the original resident-plus-s19a analysis image")
        self.cpu = Uc(UC_ARCH_MIPS, UC_MODE_MIPS32 | UC_MODE_LITTLE_ENDIAN)
        self.cpu.mem_map(0, 0x200000)
        load = struct.unpack_from("<I", image, 24)[0] & 0x1FFFFF
        self.cpu.mem_write(load, image[2048:])

    def rotation(self, angles: tuple[int, ...]) -> tuple[int, ...]:
        cpu = self.cpu
        cpu.mem_write(INPUT & 0x1FFFFF, struct.pack("<4h", *angles, 0))
        cpu.mem_write(OUTPUT & 0x1FFFFF, bytes([0xA5]) * 32)
        cpu.reg_write(UC_MIPS_REG_A0, INPUT)
        cpu.reg_write(UC_MIPS_REG_A1, OUTPUT)
        cpu.reg_write(UC_MIPS_REG_SP, 0x801FE800)
        cpu.reg_write(UC_MIPS_REG_RA, STOP)
        cpu.emu_start(ENTRY, STOP, count=1000)
        if cpu.reg_read(UC_MIPS_REG_PC) != STOP:
            raise RuntimeError("Original rotation exceeded its instruction budget")
        output = bytes(cpu.mem_read(OUTPUT & 0x1FFFFF, 32))
        if output[18:] != bytes([0xA5]) * 14:
            raise ValueError("Original routine changed matrix padding or translation")
        return struct.unpack("<9h", output[:18])


def generate(image: bytes, overlay: bytes) -> str:
    offset = 2048 + ENTRY - struct.unpack_from("<I", image, 24)[0]
    code = image[offset : offset + SIZE]
    if code != overlay[ENTRY - 0x800C3208 : ENTRY - 0x800C3208 + SIZE]:
        raise ValueError(
            "Analysis instructions differ from the extracted original overlay"
        )
    reference = RotationReference(image)
    roots = [(reference.rotation(angles), translation) for angles, translation in ROOTS]
    lines = [
        "/* Synthetic results of original MIPS execution; no original code/assets. */",
        f"/* DF2F8..DF584 SHA256 {hashlib.sha256(code).hexdigest()} */",
        "static const MATRIX fixture_roots[] = {",
    ]
    for matrix, translation in roots:
        rows = ",".join(
            "{" + ",".join(map(str, matrix[i : i + 3])) + "}" for i in (0, 3, 6)
        )
        lines.append("  {{" + rows + "},{" + ",".join(map(str, translation)) + "}},")
    lines.extend(("};", "static const AimFixture aim_fixtures[] = {"))
    for angles in itertools.product(PITCHES, YAWS, ROLLS):
        matrix = reference.rotation(angles)
        hashes = [
            geometry_hash(matrix, root, translation) for root, translation in roots
        ]
        lines.append(
            "  {{"
            + ",".join(map(str, angles))
            + "},{"
            + ",".join(map(str, matrix))
            + "},{"
            + ",".join(f"0x{value:08x}u" for value in hashes)
            + "}},"
        )
    lines.append("};\n")
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image", required=True, type=Path)
    parser.add_argument("--overlay", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    args.output.write_text(
        generate(args.image.read_bytes(), args.overlay.read_bytes()), encoding="utf-8"
    )


if __name__ == "__main__":
    main()
