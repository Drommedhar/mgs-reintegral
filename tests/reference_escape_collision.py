"""Generate wall-contact fixtures from the user's original Integral escape overlay.

Only engine boundaries are modeled. The original routine executes both hazard
vector writes, its stack frame, spark/sound decisions, and position correction.
"""

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

OVERLAY_SHA256 = "d757942aca5d36ab95741801de1f68526c3a8e128018814f25655b7d72a7c249"
BASE, ENTRY, STOP = 0x800C3208, 0x800D9C90, 0x801FF800
CONTROL, POSITION, DELTA, SPEED, MAP = (0x801C0000 + i * 256 for i in range(5))


def truncate(numerator, denominator):
    return (
        abs(numerator) // abs(denominator) * (-1 if numerator * denominator < 0 else 1)
    )


class CollisionReference:
    def __init__(self, overlay):
        if hashlib.sha256(overlay).hexdigest() != OVERLAY_SHA256:
            raise ValueError("Expected original Integral Disc 2 s19b/4bbc.b")
        self.cpu = Uc(UC_ARCH_MIPS, UC_MODE_MIPS32 | UC_MODE_LITTLE_ENDIAN)
        self.cpu.mem_map(0, 0x200000)
        self.cpu.mem_write(BASE & 0x1FFFFF, overlay)
        self.cpu.hook_add(UC_HOOK_CODE, self.boundary)
        self.inputs = (0, 0, 0, 0)
        self.effects = [0] * 5

    def put(self, address, fmt, *values):
        self.cpu.mem_write(address & 0x1FFFFF, struct.pack("<" + fmt, *values))

    def get(self, address, fmt):
        return struct.unpack(
            "<" + fmt, self.cpu.mem_read(address & 0x1FFFFF, struct.calcsize("<" + fmt))
        )

    def boundary(self, cpu, address, _size, _data):
        args = [
            cpu.reg_read(reg)
            for reg in (UC_MIPS_REG_A0, UC_MIPS_REG_A1, UC_MIPS_REG_A2, UC_MIPS_REG_A3)
        ]
        result = 0
        if address == 0x80029098:
            assert args[0] == MAP + 64 and args[2:] == [475, 12]
            assert self.get(args[1], "3h") == (1234, 1450, -5678)
            result = self.inputs[0]
        elif address == 0x80029324:
            self.put(args[0], "3h", self.inputs[1], 0, 0)
            self.put(args[0] + 8, "3h", 0x1357, -0x2468, 0x369)
        elif address == 0x80016D80:
            result = abs(self.get(args[0], "3h")[0])
        elif address in (0x80016D00, 0x80016D40):
            first, second = self.get(args[0], "3h"), self.get(args[1], "3h")
            sign = 1 if address == 0x80016D00 else -1
            self.put(args[2], "3h", *(a + sign * b for a, b in zip(first, second)))
        elif address == 0x80016DDC:
            numerator = args[3] if args[3] < 0x80000000 else args[3] - 0x100000000
            scale = truncate(numerator * 4096, args[2] or 1)
            self.put(
                args[1],
                "3h",
                *(truncate(value * scale, 4096) for value in self.get(args[0], "3h")),
            )
        elif address == 0x800DA6D8:
            self.effects[0] += 1
            self.effects[2:] = self.get(args[0] + 20, "3i")
        elif address == 0x800329C4:
            assert args[1:3] == [195, 1]
            self.effects[1] += 1
        else:
            return
        cpu.reg_write(UC_MIPS_REG_V0, result & 0xFFFFFFFF)
        cpu.reg_write(UC_MIPS_REG_PC, cpu.reg_read(UC_MIPS_REG_RA))

    def run(self, inputs):
        self.inputs = inputs
        self.effects = [0] * 5
        self.put(CONTROL, "4h", 1234, 1200, -5678, 45)
        self.put(CONTROL + 0x2C, "I", MAP)
        self.put(MAP + 8, "I", MAP + 64)
        self.put(POSITION, "4i", 110000, 220000, -330000, 44)
        self.put(DELTA, "4h", 17, 18, 19, 20)
        self.put(SPEED, "i", -141)
        self.put(0x800C3AD4, "i", inputs[2])
        self.put(0x800AB924, "i", inputs[3])
        self.put(0x800AD430, "10h3i", 4096, 0, 0, 0, 4096, 0, 0, 0, 4096, 0, 0, 0, 0)
        for register, value in zip(
            (UC_MIPS_REG_A0, UC_MIPS_REG_A1, UC_MIPS_REG_A2, UC_MIPS_REG_A3),
            (CONTROL, POSITION, SPEED, DELTA),
        ):
            self.cpu.reg_write(register, value)
        self.cpu.reg_write(UC_MIPS_REG_SP, 0x801FE000)
        self.cpu.reg_write(UC_MIPS_REG_RA, STOP)
        self.cpu.emu_start(ENTRY, STOP, count=1000)
        assert self.cpu.reg_read(UC_MIPS_REG_PC) == STOP
        assert self.get(SPEED, "i") == (-141,)
        output = [self.cpu.reg_read(UC_MIPS_REG_V0)]
        output += (
            self.get(CONTROL, "3h") + self.get(POSITION, "3i") + self.get(DELTA, "3h")
        )
        output += self.get(0x800C3AD4, "i")
        return output + self.effects


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--overlay", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    reference = CollisionReference(args.overlay.read_bytes())
    rows = []
    cases = itertools.product(
        (-1, 0, 1, 2), (0, 1, 299, 474, 475, 484, 485, 600), (0, 5, 6, 12), (1, 2)
    )
    for index, (count, distance, timer, passage) in enumerate(cases):
        inputs = (count, distance if index % 2 else -distance, timer, passage)
        output = reference.run(inputs)
        rows.append(
            "    {{"
            + ", ".join(map(str, inputs))
            + "}, {"
            + ", ".join(map(str, output))
            + "}},"
        )
    args.output.write_text(
        "/* Synthetic outcomes: original 0x800D9C90..0x800D9EBF; regenerate with reference_escape_collision.py. */\n"
        "static const CollisionFixture collision_fixtures[] = {\n"
        + "\n".join(rows)
        + "\n};\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
