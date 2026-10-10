"""Generate Ninja hit-dispatch fixtures from original Integral MIPS execution."""

import argparse
import itertools
import struct
from pathlib import Path

from unicorn.mips_const import (
    UC_MIPS_REG_A0,
    UC_MIPS_REG_PC,
    UC_MIPS_REG_RA,
    UC_MIPS_REG_SP,
    UC_MIPS_REG_V0,
)

from reference_ninja_terminal import BASE, SIZE, STOP, WORK, NinjaReference, initializer

ENTRIES = (0x800CF354, 0x800CF464, 0x800CF54C)
GAME_STATUS, HIT_COUNT = 0x800AB3CC, 0x800C3448


class HitReference(NinjaReference):
    def boundary(self, cpu, address, _size, _data):
        if address not in (0x800CDE74, 0x800CE2E8):
            return
        assert cpu.reg_read(UC_MIPS_REG_A0) == WORK
        count = struct.unpack("<i", cpu.mem_read(HIT_COUNT & 0x1FFFFF, 4))[0]
        group, state = struct.unpack("<2i", cpu.mem_read((WORK + 0x19C8) & 0x1FFFFF, 8))
        self.trace.append((address & 0xFFFF, count, group, state))
        cpu.reg_write(UC_MIPS_REG_V0, 0)
        cpu.reg_write(UC_MIPS_REG_PC, cpu.reg_read(UC_MIPS_REG_RA))

    def run(self, values):
        operation, hit, state, flags, count = values
        self.cpu.mem_write(
            WORK & 0x1FFFFF, bytes((i * 13 + 71) & 255 for i in range(SIZE))
        )
        for offset, value in ((0x19C8, 6), (0x19CC, state), (0x1A34, hit)):
            self.put(WORK + offset, "i", value)
        self.put(GAME_STATUS, "i", flags)
        self.put(HIT_COUNT, "i", count)
        self.trace = []
        before = bytes(self.cpu.mem_read(WORK & 0x1FFFFF, SIZE))
        self.cpu.reg_write(UC_MIPS_REG_A0, WORK)
        self.cpu.reg_write(UC_MIPS_REG_SP, 0x801FE000)
        self.cpu.reg_write(UC_MIPS_REG_RA, STOP)
        self.cpu.emu_start(ENTRIES[operation], STOP, count=200)
        assert self.cpu.reg_read(UC_MIPS_REG_PC) == STOP
        after = bytes(self.cpu.mem_read(WORK & 0x1FFFFF, SIZE))
        changes = [
            (offset, struct.unpack_from("<I", after, offset)[0])
            for offset in range(0, SIZE, 4)
            if before[offset : offset + 4] != after[offset : offset + 4]
        ]
        assert len(changes) <= 3 and len(self.trace) <= 1
        count = struct.unpack("<i", self.cpu.mem_read(HIT_COUNT & 0x1FFFFF, 4))[0]
        return self.cpu.reg_read(UC_MIPS_REG_V0), count, changes, self.trace


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--overlay", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    reference = HitReference(args.overlay.read_bytes())
    lines = [
        "/* Synthetic inputs; expected results from original Integral s08b MIPS. */",
        "static const NinjaHitFixture ninja_hit_fixtures[] = {",
    ]
    cases = itertools.product(
        range(3),
        (-2147483648, -1, 0, 1, 2, 3, 4, 5, 6, 7),
        (-1, 3, 4, 23),
        (0, 1, 256, 257),
        (0, 2),
    )
    for values in cases:
        result, count, changes, trace = reference.run(values)
        encoded_changes = ", ".join(initializer(change) for change in changes) or "{0}"
        encoded_trace = initializer(trace[0]) if trace else "{0}"
        lines.append(
            f"  {{{initializer(values)}, {result}, {count}, {len(changes)}, "
            f"{{{encoded_changes}}}, {len(trace)}, {encoded_trace}}},"
        )
    args.output.write_text("\n".join(lines + ["};", ""]), encoding="utf-8")
    print(f"Generated {len(lines) - 2} Ninja hit-dispatch cases from {BASE:#x} overlay")


if __name__ == "__main__":
    main()
