"""Execute the retail Liquid climb action and its real two-vector hazard reader."""

import argparse
import hashlib
import struct
from pathlib import Path

from unicorn import Uc
from unicorn.mips_const import (
    UC_MIPS_REG_A0,
    UC_MIPS_REG_A1,
    UC_MIPS_REG_PC,
    UC_MIPS_REG_RA,
    UC_MIPS_REG_SP,
    UC_MIPS_REG_V0,
)

from reference_boss_terminal import REGISTERS, STOP, WORK, Reference, hash_bytes

MAP, HAZARD, SCRATCH = 0x80182000, 0x80183000, 0x1F800000
TICKS = (-1, 0, 1, 25, 26, 27, 57, 58, 59, 60, 61, 79, 80, 100)
TYPES = (-1, 0, 1, 2, 3, 4, 5, 6, 7, 8)
POSITIONS = (
    (100, -200, 300, 7),
    (32760, -32760, -32760, -8),
    (-32760, 32760, 32760, 9),
)
NEAR = (
    (17, -31, 271, -371),
    (32767, -32768, -32768, 32767),
    (-32768, 32767, 1337, -1337),
)


def initial_work(seed: int) -> bytearray:
    data = bytearray((index * 37 + seed * 11 + 3) & 255 for index in range(2636))
    struct.pack_into("<I", data, 0x4C, MAP)
    struct.pack_into("<I", data, 0x92C, 0x800CBB50)
    struct.pack_into("<i", data, 0x914, TYPES[seed % 10])
    struct.pack_into("<h", data, 0xB6, seed // 140 % 2)
    struct.pack_into("<h", data, 0x98, -1234 + seed)
    struct.pack_into("<4h", data, 0xA44, *POSITIONS[seed // 280])
    return data


class ClimbReference(Reference):
    def __init__(self, image: bytes):
        super().__init__(image)
        self.cpu.mem_map(SCRATCH, 0x1000)

    def boundary(self, address: int, arguments: list[int]) -> int:
        first, second, third, fourth = arguments
        if address == 0x800C722C:
            if first != WORK + 0x20 or second != WORK + 0x6E:
                raise ValueError("Climb classification received incorrect pointers")
            self.event(0, hash_bytes(self.read(first, 8)))
            self.cpu.mem_write(
                second & 0x1FFFFF, struct.pack("<h", self.seed * 7 - 3000)
            )
            return TYPES[self.seed % 10]
        if address == 0x80034CD4:
            self.event(1, first - WORK, second, third, fourth)
        elif address == 0x80029098:
            flags = self.word(self.cpu.reg_read(UC_MIPS_REG_SP) + 16)
            self.event(2, first, second - WORK, third, fourth, flags)
            x1, z1, x2, z2 = NEAR[self.seed // 280]
            self.cpu.mem_write(SCRATCH + 0x78, struct.pack("<hh", x1, z1))
            self.cpu.mem_write(SCRATCH + 0x94, struct.pack("<hh", x2, z2))
            return 1 + self.seed % 2
        elif address == 0x80032858:
            self.event(4, first - WORK, second, hash_bytes(self.read(first, 8)))
        return 0

    def hook(self, cpu: Uc, address: int, size: int, context: object) -> None:
        del size, context
        if address == 0x800CBCB8:
            pointer = cpu.reg_read(UC_MIPS_REG_SP) + 0x18
            values = struct.unpack("<8h", self.read(pointer, 16))
            self.event(3, *values[:3], *values[4:7])
            return
        if address not in (0x8008BBA0, 0x800C722C, 0x80034CD4, 0x80029098, 0x80032858):
            return
        result = self.boundary(
            address, [cpu.reg_read(register) for register in REGISTERS]
        )
        cpu.reg_write(UC_MIPS_REG_V0, result & 0xFFFFFFFF)
        cpu.reg_write(UC_MIPS_REG_PC, cpu.reg_read(UC_MIPS_REG_RA))

    def run_climb(self, seed: int) -> tuple[int, int, int]:
        self.seed, self.trace = seed, []
        cpu = self.cpu
        cpu.mem_write(0, bytes(0x200000))
        load = struct.unpack_from("<I", self.image, 24)[0] & 0x1FFFFF
        cpu.mem_write(load, self.image[2048:])
        cpu.mem_write(WORK & 0x1FFFFF, bytes(initial_work(seed)))
        self.put(MAP + 8, HAZARD)
        for index in range(40):
            cpu.mem_write(0xC3318 + index * 2, struct.pack("<h", index * 13 - 200))
        cpu.reg_write(UC_MIPS_REG_A0, WORK)
        cpu.reg_write(UC_MIPS_REG_A1, TICKS[seed // 10 % 14] & 0xFFFFFFFF)
        cpu.reg_write(UC_MIPS_REG_SP, 0x801FE800)
        cpu.reg_write(UC_MIPS_REG_RA, STOP)
        cpu.emu_start(0x800CBB50, STOP, count=10000)
        if cpu.reg_read(UC_MIPS_REG_PC) != STOP:
            raise RuntimeError("Climb action exceeded its instruction budget")
        trace = struct.pack(f"<{len(self.trace)}I", *self.trace)
        return hash_bytes(self.read(WORK, 2636)), hash_bytes(trace), len(self.trace)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    image = args.image.read_bytes()
    reference = ClimbReference(image)
    base = struct.unpack_from("<I", image, 24)[0]
    offset = 2048 + 0x800CBB50 - base
    code_hash = hashlib.sha256(image[offset : offset + 0x3E8]).hexdigest()
    offset = 2048 + 0x80029324 - base
    reader_hash = hashlib.sha256(image[offset : offset + 0x3C]).hexdigest()
    lines = [
        f"/* Original climb code SHA256: {code_hash} */",
        f"/* Original hazard reader SHA256: {reader_hash} */",
        "static const LiquidClimbFixture liquid_climb_fixtures[] = {",
    ]
    for seed in range(840):
        state, trace, count = reference.run_climb(seed)
        lines.append(f"    {{0x{state:08x}u, 0x{trace:08x}u, {count}}},")
    lines.append("};")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("Generated 840 original-MIPS climb and hazard-reader comparisons.")


if __name__ == "__main__":
    main()
