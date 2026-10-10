"""Regenerate terminal-state fixtures by executing privately supplied retail MIPS."""

import argparse
import hashlib
import itertools
import struct
from pathlib import Path

from unicorn import (
    UC_ARCH_MIPS,
    UC_HOOK_CODE,
    UC_MODE_LITTLE_ENDIAN,
    UC_MODE_MIPS32,
    Uc,
)
from unicorn.mips_const import (
    UC_MIPS_REG_A0,
    UC_MIPS_REG_A1,
    UC_MIPS_REG_A2,
    UC_MIPS_REG_A3,
    UC_MIPS_REG_PC,
    UC_MIPS_REG_RA,
    UC_MIPS_REG_SP,
    UC_MIPS_REG_V0,
)

WORK, STOP, DEFAULTS = 0x80180000, 0x801FF800, 0x800C36D4
STATUS, GAMEOVER = 0x800AB3CC, 0x800AB3D4
REGISTERS = (UC_MIPS_REG_A0, UC_MIPS_REG_A1, UC_MIPS_REG_A2, UC_MIPS_REG_A3)
REX_TIMERS = (0, 30, 31, 32, 33, 38, 39, 40, 100)
LIQUID_TIMERS = (0, 1, 2, -1, 39)
PROCEDURES = (-1, 0, 1, 0x7FFF, 0xFFFF)


def hash_bytes(data: bytes) -> int:
    result = 2166136261
    for byte in data:
        result = ((result ^ byte) * 16777619) & 0xFFFFFFFF
    return result


def initial_work(kind: int, seed: int) -> bytearray:
    size = 6904 if kind < 2 else 2636
    data = bytearray((index * 37 + seed * 11 + 3) & 255 for index in range(size))
    values = {0x968: LIQUID_TIMERS[seed % 5], 0x9E0: PROCEDURES[seed // 5 % 5]}
    if kind < 2:
        values = {
            0x1AA8: REX_TIMERS[seed % 9],
            0x1960: seed // 9 % 3,
            0x1954: (0, 2, 11, 7)[seed // 54 % 4],
            0x1958: 13,
            0x1764: 0x1234,
            0x1768: 0xABCD,
            0x1ABC: 1000,
            0x1AC0: (0, 1, 999, 1000)[seed // 54 % 4],
            0x1AC4: (1000, 501, 0, -1)[seed // 54 % 4],
        }
    for offset, value in values.items():
        struct.pack_into("<i", data, offset, value)
    return data


class Reference:
    def __init__(self, image: bytes):
        if image[:8] != b"PS-X EXE":
            raise ValueError("Expected an extracted resident-plus-overlay PS-X EXE")
        self.image = image
        self.cpu = Uc(UC_ARCH_MIPS, UC_MODE_MIPS32 | UC_MODE_LITTLE_ENDIAN)
        self.cpu.mem_map(0, 0x200000)
        self.cpu.hook_add(UC_HOOK_CODE, self.hook)
        self.kind = self.seed = self.random_index = 0
        self.trace: list[int] = []

    def read(self, address: int, size: int) -> bytes:
        return bytes(self.cpu.mem_read(address & 0x1FFFFF, size))

    def put(self, address: int, value: int) -> None:
        self.cpu.mem_write(address & 0x1FFFFF, struct.pack("<I", value & 0xFFFFFFFF))

    def word(self, address: int) -> int:
        return struct.unpack("<I", self.read(address, 4))[0]

    def event(self, *values: int) -> None:
        self.trace.extend(value & 0xFFFFFFFF for value in values)

    def callback(self, arguments: list[int]) -> int:
        self.event(4, arguments[0], arguments[1], self.word(STATUS))
        offset = 0x1AA8 if self.kind < 2 else 0x968
        self.event(self.word(WORK + offset))
        if self.seed & 1:
            self.put(WORK + offset, 91)
            self.put(STATUS, self.word(STATUS) ^ 0x100)
        return 0x1357

    def hook(self, cpu: Uc, address: int, size: int, _context: object) -> None:
        del size
        addresses = (0x800170BC, 0x80038DE0, 0x800CE868, 0x800151C8, 0x8001FF2C)
        if address not in addresses:
            return
        arguments = [cpu.reg_read(register) for register in REGISTERS]
        result = 0
        if address == 0x800170BC:
            result = (-128, -1, 0, 127)[(self.seed + self.random_index) % 4]
            self.random_index += 1
            self.event(0, arguments[0], result)
        elif address == 0x80038DE0:
            pointer = self.word(cpu.reg_read(UC_MIPS_REG_SP) + 16)
            self.event(1, *arguments, pointer - WORK)
        elif address == 0x800CE868:
            self.event(2, *arguments[:2])
        elif address == 0x800151C8:
            if arguments[0] != WORK:
                raise ValueError("DestroyActor received the wrong actor")
            self.event(3, self.word(STATUS), self.word(WORK + 0x1AA8))
            self.put(WORK + 8, 0x12345678)
        else:
            result = self.callback(arguments)
        cpu.reg_write(UC_MIPS_REG_V0, result & 0xFFFFFFFF)
        cpu.reg_write(UC_MIPS_REG_PC, cpu.reg_read(UC_MIPS_REG_RA))

    def run(self, kind: int, seed: int) -> tuple[int, int, int]:
        self.kind, self.seed, self.random_index = kind, seed, 0
        self.trace = []
        cpu = self.cpu
        cpu.mem_write(0, bytes(0x200000))
        load = struct.unpack_from("<I", self.image, 24)[0] & 0x1FFFFF
        cpu.mem_write(load, self.image[2048:])
        cpu.mem_write(WORK & 0x1FFFFF, bytes(initial_work(kind, seed)))
        cpu.mem_write(DEFAULTS & 0x1FFFFF, bytes([0xA5]) * 6904)
        self.put(STATUS, (0, 0x8000, 0x800000, 0xA5838123)[seed // 27 % 4])
        self.put(GAMEOVER, seed // 27 % 2)
        cpu.reg_write(UC_MIPS_REG_A0, WORK)
        cpu.reg_write(UC_MIPS_REG_SP, 0x801FE800)
        cpu.reg_write(UC_MIPS_REG_RA, STOP)
        cpu.emu_start((0x800DB268, 0x800DB478, 0x800CE6B4)[kind], STOP, count=30000)
        if cpu.reg_read(UC_MIPS_REG_PC) != STOP:
            raise RuntimeError(
                "Terminal routine did not return within its instruction budget"
            )
        data = self.read(WORK, 6904 if kind < 2 else 2636)
        if kind < 2:
            data += self.read(DEFAULTS, 6904)
        data += self.read(STATUS, 4)
        trace = struct.pack(f"<{len(self.trace)}I", *self.trace)
        return hash_bytes(data), hash_bytes(trace), len(self.trace)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rex-image", type=Path, required=True)
    parser.add_argument("--liquid-image", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    images = [args.rex_image.read_bytes(), args.liquid_image.read_bytes()]
    references = [Reference(image) for image in images]
    lines = ["/* Synthetic state hashes from complete original MIPS terminal routines."]
    lines.extend(
        f" * Analysis image SHA256: {hashlib.sha256(image).hexdigest()}"
        for image in images
    )
    lines.append(" */\nstatic const BossTerminalFixture boss_terminal_fixtures[] = {")
    cases = itertools.chain(
        ((kind, seed) for kind in range(2) for seed in range(432)),
        ((2, seed) for seed in range(100)),
    )
    for kind, seed in cases:
        state, trace, count = references[kind // 2].run(kind, seed)
        lines.append(
            f"    {{{kind}, {seed}, 0x{state:08x}u, 0x{trace:08x}u, {count}}},"
        )
    lines.append("};")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("Generated 964 original-MIPS terminal-state and callback-trace comparisons.")


if __name__ == "__main__":
    main()
