"""Generate synthetic Ninja terminal cases by executing retail Integral MIPS.

The original terminal dispatcher, timers, route helpers and callback gates run
unchanged. Only stream, GCL, hazard and sphere-constructor boundaries are hooked.
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
    UC_MIPS_REG_PC,
    UC_MIPS_REG_RA,
    UC_MIPS_REG_SP,
    UC_MIPS_REG_V0,
)

SHA256 = "21c5534dd17e5579404b2b0b2f3c47fb324b27a363a108669e3818a3dee15ded"
BASE, WORK, MAP, HAZARD, STOP = (
    0x800C3208,
    0x801C0000,
    0x801D0000,
    0x801D1000,
    0x801FF800,
)
SIZE = 0x1B34
ENTRIES = (0x800D2DB0, 0x800D2158, 0x800D1738)


def cases():
    alive = ((0, 768), (0, 0), (0, -1), (1, 768))
    for timer, route, flags, proc, life in itertools.product(
        (-1, 0, 1, 119, 120, 121, 299, 300),
        (0, 2, 3, 4),
        range(4),
        (-1, 0, 0x39BD),
        alive,
    ):
        yield (0, 23, timer, route, flags, proc, -1, *life, 1)
    for phase, timer in itertools.product((0, 22, 27, 29), (-1, 0, 29, 30, 31)):
        yield (0, phase, timer, 3, 0, 0x39BD, -1, 0, 768, 1)
    for timer, proc, stream, life in itertools.product(
        (-1, 0, 58, 59, 60, 68, 69, 70, 159, 160, 161),
        (-1, 0, 0xD4E2),
        (-1, 0, 1),
        alive,
    ):
        yield (1, 0, timer, 2, 0, proc, stream, *life, 1)
    for timer, proc, stream, life in itertools.product(
        (-1, 0, 1, 2, 3),
        (-1, 0, 0xAEEA),
        (-1, 0, 1),
        alive,
    ):
        yield (2, 38, timer, 0, 0, proc, stream, *life, 1)
    yield (0, 23, 0, 3, 1, 0x39BD, -1, 0, 768, 310)
    yield (1, 0, 0, 2, 0, 0xD4E2, -1, 0, 768, 180)
    yield (2, 38, 0, 0, 0, 0xAEEA, -1, 0, 768, 6)


class NinjaReference:
    def __init__(self, overlay):
        if hashlib.sha256(overlay).hexdigest() != SHA256:
            raise ValueError("Expected original Integral Disc 1 s08b/479c.b")
        self.cpu = Uc(UC_ARCH_MIPS, UC_MODE_MIPS32 | UC_MODE_LITTLE_ENDIAN)
        self.cpu.mem_map(0, 0x200000)
        self.cpu.mem_write(BASE & 0x1FFFFF, overlay)
        self.cpu.hook_add(UC_HOOK_CODE, self.boundary)
        self.trace = []
        self.stream = 0

    def put(self, address, fmt, *values):
        self.cpu.mem_write(address & 0x1FFFFF, struct.pack("<" + fmt, *values))

    def observe(self, event, first, second):
        state, timer = struct.unpack(
            "<2i", self.cpu.mem_read((WORK + 0x19CC) & 0x1FFFFF, 8)
        )
        self.trace.append((event, first, second, timer, state))

    def boundary(self, cpu, address, _size, _data):
        args = [
            cpu.reg_read(reg)
            for reg in (UC_MIPS_REG_A0, UC_MIPS_REG_A1, UC_MIPS_REG_A2)
        ]
        result = 0
        if address == 0x80037CD8:
            result = self.stream
            self.observe(1, self.stream, 0)
        elif address == 0x80037D64:
            self.observe(2, 0, 0)
        elif address == 0x80037E40:
            assert args[1] == 0
            self.observe(3, args[0], args[1])
        elif address == 0x8001FF2C:
            assert args[1] == 0
            self.observe(4, args[0], args[1])
        elif address == 0x800D9834:
            assert args[:2] == [WORK + 0x9C, WORK + 0x1A04]
            self.observe(5, 0x9C, 0x1A04)
        elif address == 0x8005C6C4:
            assert args == [HAZARD, WORK + 0x1968, 0xFFFFFFFF]
            vector = struct.unpack("<4h", cpu.mem_read((WORK + 0x1968) & 0x1FFFFF, 8))
            result = 0x2345
            self.observe(6, vector[0], vector[2])
        else:
            return
        cpu.reg_write(UC_MIPS_REG_V0, result & 0xFFFFFFFF)
        cpu.reg_write(UC_MIPS_REG_PC, cpu.reg_read(UC_MIPS_REG_RA))

    def initialize(self, values):
        _, phase, timer, route, flags, proc, self.stream, game_over, life, _ = values
        self.cpu.mem_write(
            WORK & 0x1FFFFF, bytes((i * 13 + 71) & 255 for i in range(SIZE))
        )
        fields = {
            0x4C: MAP,
            0x19CC: phase,
            0x19D0: timer,
            0x19E0: route,
            0x19A4: flags & 1,
            0x19A8: (flags >> 1) & 1,
            0x1A8C: proc,
            0x1A90: proc,
            0x1A94: proc,
            0x1A28: 2345,
            0x1A9C: 0x4501,
            0x1AE0: 0x4512,
        }
        for offset, value in fields.items():
            self.put(WORK + offset, "I", value & 0xFFFFFFFF)
        self.put(MAP + 8, "I", HAZARD)
        self.put(0x800AB3D4, "i", game_over)
        self.put(0x800B4DAE, "h", life)
        self.put(0x800C3454, "i", 0x12)
        self.put(0x800C3458, "4h", 101, -202, 303, 0x55AA)
        for index in range(3):
            self.put(
                0x800C34F8 + index * 8,
                "4h",
                400 + index,
                -500 - index,
                600 + index,
                700 + index,
            )
        self.trace = []

    def run(self, values):
        self.initialize(values)
        before = bytes(self.cpu.mem_read(WORK & 0x1FFFFF, SIZE))
        result = 0
        for _ in range(values[9]):
            self.cpu.reg_write(UC_MIPS_REG_A0, WORK)
            self.cpu.reg_write(UC_MIPS_REG_SP, 0x801FE000)
            self.cpu.reg_write(UC_MIPS_REG_RA, STOP)
            self.cpu.emu_start(ENTRIES[values[0]], STOP, count=2000)
            assert self.cpu.reg_read(UC_MIPS_REG_PC) == STOP
            if values[0] == 2:
                result = self.cpu.reg_read(UC_MIPS_REG_V0)
        after = bytes(self.cpu.mem_read(WORK & 0x1FFFFF, SIZE))
        changes = []
        for offset in range(0, SIZE, 4):
            if before[offset : offset + 4] != after[offset : offset + 4]:
                changes.append((offset, struct.unpack_from("<I", after, offset)[0]))
        assert len(changes) <= 16 and len(self.trace) <= 8
        return result, changes, self.trace


def initializer(values):
    return "{" + ", ".join(map(str, values)) + "}"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--overlay", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    reference = NinjaReference(args.overlay.read_bytes())
    rows = []
    for inputs in cases():
        result, changes, trace = reference.run(inputs)
        changed = (
            "{"
            + ", ".join(f"{{{offset}, 0x{value:08x}u}}" for offset, value in changes)
            + "}"
            if changes
            else "{{0, 0}}"
        )
        events = (
            "{" + ", ".join(initializer(event) for event in trace) + "}"
            if trace
            else "{{0}}"
        )
        rows.append(
            f"    {{{initializer(inputs)}, {result}, {len(changes)}, {changed}, {len(trace)}, {events}}},"
        )
    args.output.write_text(
        "/* Synthetic retail-MIPS terminal outcomes; regenerate with reference_ninja_terminal.py. */\n"
        "static const NinjaTerminalFixture ninja_terminal_fixtures[] = {\n"
        + "\n".join(rows)
        + "\n};\n",
        encoding="utf-8",
    )
    print(f"Generated {len(rows)} original-MIPS Ninja terminal cases")


if __name__ == "__main__":
    main()
