"""Execute the original Integral Tank completion callback to produce trace hashes.

Requires a locally supplied s05a/473b.b and Python Unicorn. No original code or
assets are copied into the generated header.
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
    UC_MIPS_REG_PC,
    UC_MIPS_REG_RA,
    UC_MIPS_REG_SP,
    UC_MIPS_REG_V0,
)

OVERLAY_HASH = "fd08923d1e1ad01b8638f7e8f4a101e270a5f399f3d1afed47abca7532a8c081"
BASE, WORK, MAP, HAZARD = 0x800C3208, 0x80100000, 0x80110000, 0x80111000
TARGETS, CHILD1, CHILD2, STOP = 0x80120000, 0x80130000, 0x80131000, 0x80001000
HOOKS = (0x800AB3DC, 0x800AB3E0, 0x800AB3E8, 0x800AB3EC, 0x800AB3F0)
ACCELERATIONS = (-100001, -1000, -1, 0, 999, 10000, 100000)
CALLS = {
    0x800151C8: 1,
    0x8001FEFC: 2,
    0x8006FE44: 3,
    0x8006FFE8: 4,
    0x80034BF8: 5,
    0x8002D4B0: 6,
    0x800260CC: 7,
    0x8001FF2C: 8,
}


def read32(machine: Uc, address: int) -> int:
    return struct.unpack("<I", machine.mem_read(address & 0x1FFFFFFF, 4))[0]


def write32(machine: Uc, address: int, value: int) -> None:
    machine.mem_write(address & 0x1FFFFFFF, struct.pack("<I", value & 0xFFFFFFFF))


def event_arguments(machine: Uc, event: int) -> list[int]:
    first, second = (machine.reg_read(reg) for reg in (UC_MIPS_REG_A0, UC_MIPS_REG_A1))
    if event == 1:
        return [{CHILD1: 1, CHILD2: 2}[first]]
    if event == 2:
        count = struct.unpack("<H", machine.mem_read(second & 0x1FFFFFFF, 2))[0]
        argv = read32(machine, second + 4)
        return [first, count] + [
            read32(machine, argv + 4 * index) for index in range(count)
        ]
    if event in (3, 4):
        assert first == HAZARD
        return [second - WORK]
    if event in (5, 7):
        return [first - WORK]
    if event == 6:
        assert (first - TARGETS) % 0x48 == 0
        return [(first - TARGETS) // 0x48]
    assert event == 8 and second == 0
    return [first]


def trace_call(machine: Uc, address: int, _size: int, trace: list[int]) -> None:
    if address == STOP:
        machine.emu_stop()
        return
    if address not in CALLS:
        assert 0x800D5E30 <= address <= 0x800D6278, hex(address)
        return
    event = CALLS[address]
    trace.extend([event] + event_arguments(machine, event))
    flags = sum(
        bool(read32(machine, location)) << bit for bit, location in enumerate(HOOKS)
    )
    flags |= bool(read32(machine, 0x800C362C)) << 5
    motion = struct.unpack("<h", machine.mem_read(0xAB3E6, 2))[0]
    trace.extend((flags, motion))
    machine.reg_write(UC_MIPS_REG_V0, 0)
    machine.reg_write(UC_MIPS_REG_PC, machine.reg_read(UC_MIPS_REG_RA))


def seed_case(machine: Uc, values: tuple[int, ...]) -> bytes:
    mode, restore, victory, children, acceleration = values
    machine.mem_write(WORK & 0x1FFFFFFF, bytes(0x139C))
    fields = {
        0x4C: MAP,
        0xD54: mode,
        0xD64: acceleration,
        0xD68: int(acceleration / 7),
        0xE08: children - 2,
        0xE0C: 1234,
        0xE10: -42,
        0xE1C: restore,
        0xE20: victory,
        0xEDC: CHILD1 if children & 1 else 0,
        0xEB0: CHILD2 if children & 2 else 0,
    }
    for offset, value in fields.items():
        write32(machine, WORK + offset, value)
    for index in range(10):
        write32(machine, WORK + 0x718 + 4 * index, TARGETS + 0x48 * index)
    write32(machine, MAP + 8, HAZARD)
    for address in HOOKS:
        write32(machine, address, 1)
    machine.mem_write(0xAB3E6, struct.pack("<h", 42))
    write32(machine, 0x800C362C, WORK)
    machine.reg_write(UC_MIPS_REG_A0, WORK)
    machine.reg_write(UC_MIPS_REG_SP, 0x801F0000)
    machine.reg_write(UC_MIPS_REG_RA, STOP)
    return bytes(machine.mem_read(WORK & 0x1FFFFFFF, 0x139C))


def execute_case(
    machine: Uc, trace: list[int], values: tuple[int, ...]
) -> tuple[int, int]:
    initial = seed_case(machine, values)
    trace.clear()
    machine.emu_start(0x800D5E30, STOP, count=10000)
    assert machine.reg_read(UC_MIPS_REG_PC) == STOP
    assert bytes(machine.mem_read(WORK & 0x1FFFFFFF, 0x139C)) == initial
    assert all(read32(machine, address) == 0 for address in HOOKS)
    assert read32(machine, 0x800C362C) == 0
    digest = 2166136261
    for value in trace:
        digest = ((digest ^ (value & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
    return digest, len(trace)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--overlay", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    arguments = parser.parse_args()
    original = arguments.overlay.read_bytes()
    if hashlib.sha256(original).hexdigest() != OVERLAY_HASH:
        raise ValueError(
            "The supplied overlay is not the verified Integral s05a/473b.b"
        )
    machine = Uc(UC_ARCH_MIPS, UC_MODE_MIPS32 | UC_MODE_LITTLE_ENDIAN)
    machine.mem_map(0, 0x200000)
    machine.mem_write(BASE & 0x1FFFFFFF, original)
    trace: list[int] = []
    machine.hook_add(UC_HOOK_CODE, trace_call, trace)
    cases = itertools.product(
        (0, 1, 4, 5, 6), (-1, 0, 0x5678), (-1, 0, 0xABCD), range(4), ACCELERATIONS
    )
    outputs = [execute_case(machine, trace, values) for values in cases]
    rows = [f"  {{0x{digest:08x}u, {length}}}," for digest, length in outputs]
    header = "/* Original Integral 800D5E30..800D6278 call-trace hashes. */\n"
    header += "static const Expected expected[] = {\n" + "\n".join(rows) + "\n};\n"
    arguments.output.write_text(header, encoding="utf-8")
    print(f"Generated {len(outputs)} original-MIPS Tank completion fixtures")


if __name__ == "__main__":
    main()
