"""Run the retail Liquid dispatcher with observable action callback boundaries."""

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

from reference_boss_terminal import STOP, WORK, Reference, hash_bytes

TARGET, ATTACK, OBJECTS = 0x80181000, 0x80181100, 0x80182000
PRIMARY, SECONDARY, DEFAULT = 0x801F0000, 0x801F0100, 0x800C82A4
TIMERS = (0, 1, -1, 39, 0x7FFFFFFF, -0x80000000)
VELOCITIES = (-32769, -1, 0, 1, 32767, 65537)
SPHERES = (-2, 449, 450, 451, 1000, -32768)


def initial_work(seed: int) -> bytearray:
    data = bytearray((index * 37 + seed * 11 + 3) & 255 for index in range(2636))
    words = {
        0x9C: OBJECTS,
        0x8BC: TARGET,
        0x8C0: ATTACK,
        0x92C: PRIMARY if seed // 6 % 3 else 0,
        0x930: SECONDARY if seed // 18 % 2 else 0,
        0x934: TIMERS[seed % 6],
        0x938: TIMERS[(seed + 3) % 6],
        0x948: seed // 9 % 6 - 1,
        0x9A4: seed // 144 % 6 - 1,
        0x90C: VELOCITIES[seed // 27 % 6],
        0x910: 0x1234FFFF,
    }
    for offset, value in words.items():
        struct.pack_into("<I", data, offset, value & 0xFFFFFFFF)
    struct.pack_into("<h", data, 0x56, SPHERES[seed % 6])
    struct.pack_into("<h", data, 0x22, -30000 + seed * 17)
    struct.pack_into("<h", data, 0xB4, 1234 if seed & 1 else -1234)
    data[0x77] = seed // 2 % 2
    return data


class DispatchReference(Reference):
    def action(self, address: int, tick: int) -> None:
        kind = {DEFAULT: 0, PRIMARY: 1, SECONDARY: 2}[address]
        self.event(
            kind,
            tick,
            self.word(WORK + 0x934),
            self.word(WORK + 0x938),
            self.word(WORK + 0x940),
            self.word(WORK + 0x944),
            self.word(WORK + 0x9A8),
        )
        self.event(
            struct.unpack("<H", self.read(TARGET, 2))[0],
            struct.unpack("<H", self.read(ATTACK, 2))[0],
        )
        if kind < 2:
            self.put(WORK + 0x940, int(tick == 0))
            if self.seed // 6 % 3 == 2:
                self.put(WORK + 0x934, 41)
                self.put(WORK + 0x938, -3 if self.seed & 1 else 0)
                self.put(WORK + 0x930, 0 if self.seed // 18 % 2 else SECONDARY)
                self.put(WORK + 0x944, self.seed & 1)
        else:
            self.put(WORK + 0x9A8, (tick ^ 0x1234) & 0xFFFFFFFF)

    def hook(self, cpu: Uc, address: int, size: int, context: object) -> None:
        del size, context
        if address not in (PRIMARY, SECONDARY, DEFAULT, 0x80033054):
            return
        first, second = (
            cpu.reg_read(register) for register in (UC_MIPS_REG_A0, UC_MIPS_REG_A1)
        )
        if address == 0x80033054:
            self.event(3, first, second - WORK, hash_bytes(self.read(second, 8)))
            self.cpu.mem_write(
                second & 0x1FFFFF, struct.pack("<hh", self.seed * 19, -self.seed * 7)
            )
        else:
            if first != WORK:
                raise ValueError("Action did not receive its actor")
            self.action(address, second)
        cpu.reg_write(UC_MIPS_REG_V0, 0)
        cpu.reg_write(UC_MIPS_REG_PC, cpu.reg_read(UC_MIPS_REG_RA))

    def run_dispatch(self, seed: int) -> tuple[int, int, int, int]:
        self.seed, self.trace = seed, []
        cpu = self.cpu
        cpu.mem_write(0, bytes(0x200000))
        load = struct.unpack_from("<I", self.image, 24)[0] & 0x1FFFFF
        cpu.mem_write(load, self.image[2048:])
        cpu.mem_write(WORK & 0x1FFFFF, bytes(initial_work(seed)))
        for address in (TARGET, ATTACK, OBJECTS):
            cpu.mem_write(address & 0x1FFFFF, bytes([0xA5]) * 72)
        self.put(0x800ABA50, (0, 0x20, 0x40, 0x60)[seed // 36 % 4])
        cpu.reg_write(UC_MIPS_REG_A0, WORK)
        cpu.reg_write(UC_MIPS_REG_SP, 0x801FE800)
        cpu.reg_write(UC_MIPS_REG_RA, STOP)
        cpu.emu_start(0x800CC2A0, STOP, count=10000)
        if cpu.reg_read(UC_MIPS_REG_PC) != STOP:
            raise RuntimeError("Dispatcher exceeded its instruction budget")
        data = self.read(WORK, 2636)
        for address in (TARGET, ATTACK, OBJECTS):
            data += self.read(address, 72)
        trace = struct.pack(f"<{len(self.trace)}I", *self.trace)
        return (
            hash_bytes(data),
            hash_bytes(trace),
            len(self.trace),
            cpu.reg_read(UC_MIPS_REG_V0),
        )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    image = args.image.read_bytes()
    reference = DispatchReference(image)
    offset = 2048 + 0x800CC2A0 - struct.unpack_from("<I", image, 24)[0]
    code_hash = hashlib.sha256(image[offset : offset + 0x1E8]).hexdigest()
    lines = [
        f"/* Original dispatcher code SHA256: {code_hash} */",
        "static const LiquidDispatchFixture liquid_dispatch_fixtures[] = {",
    ]
    for seed in range(864):
        state, trace, count, result = reference.run_dispatch(seed)
        lines.append(
            f"    {{0x{state:08x}u, 0x{trace:08x}u, {count}, 0x{result:08x}u}},"
        )
    lines.append("};")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("Generated 864 original-MIPS dispatcher and callback comparisons.")


if __name__ == "__main__":
    main()
