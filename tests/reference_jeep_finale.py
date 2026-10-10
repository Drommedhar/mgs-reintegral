"""Generate synthetic finale traces by executing the user's retail escape overlay.

Requires Unicorn; ordinary CTest runs use the checked-in resulting fixtures.
The engine boundary records fade, vibration, and script calls. Road routing and
the complete finale instruction range execute unchanged original instructions.
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
    UC_MIPS_REG_S2,
    UC_MIPS_REG_SP,
    UC_MIPS_REG_V0,
)

OVERLAY_SHA256 = "d757942aca5d36ab95741801de1f68526c3a8e128018814f25655b7d72a7c249"
OVERLAY_BASE = 0x800C3208
FINALE_START, FINALE_END = 0x800CDE24, 0x800CDEE8
WORK, CONTROL, SYSTEM = 0x801C0000, 0x801D0000, 0x800DE658
WORK_SIZE = 0xC84
GAME_OVER = 0x800AB3D4
TIMERS = (0, 1, 29, 30, 31, 69, 70, 71, -1, 2147483647)
POSITIONS = (-30000, -12000, 0, 9599, 9600, 30000)


class FinaleReference:
    def __init__(self, overlay: bytes):
        if hashlib.sha256(overlay).hexdigest() != OVERLAY_SHA256:
            raise ValueError("Expected original Integral Disc 2 s19b/4bbc.b")
        self.cpu = Uc(UC_ARCH_MIPS, UC_MODE_MIPS32 | UC_MODE_LITTLE_ENDIAN)
        self.cpu.mem_map(0, 0x200000)
        self.cpu.mem_write(OVERLAY_BASE & 0x1FFFFF, overlay)
        self.events = []
        self.reached_end = False
        self.cpu.hook_add(UC_HOOK_CODE, self.boundary)

    def put(self, address: int, format_string: str, *values: int) -> None:
        self.cpu.mem_write(
            address & 0x1FFFFF, struct.pack("<" + format_string, *values)
        )

    def boundary(self, cpu: Uc, address: int, _size: int, _data) -> None:
        if address == FINALE_END:
            self.reached_end = True
            cpu.emu_stop()
            return
        calls = {0x800DAB54: 1, 0x8005D58C: 2, 0x8001FF2C: 3}
        if address not in calls:
            return
        kind = calls[address]
        first, second = (
            cpu.reg_read(register) for register in (UC_MIPS_REG_A0, UC_MIPS_REG_A1)
        )
        if kind == 2:
            first -= 0x800C36FC
        self.events.append((kind, first, second))
        cpu.reg_write(UC_MIPS_REG_V0, 0)
        cpu.reg_write(UC_MIPS_REG_PC, cpu.reg_read(UC_MIPS_REG_RA))

    def prepare(
        self, timer: int, procedure: int, game_over: int, tail: int, position: int
    ) -> None:
        self.cpu.mem_write(WORK & 0x1FFFFF, bytes(WORK_SIZE))
        self.cpu.mem_write(SYSTEM & 0x1FFFFF, bytes(0x16C))
        self.put(WORK + 0xC6C, "i", tail)
        self.put(WORK + 0xC78, "i", procedure)
        self.put(WORK + 0xC80, "i", timer)
        self.put(SYSTEM + 4, "I", CONTROL)
        self.put(CONTROL + 4, "h", position)
        self.put(0x800DE5B0, "I", WORK)
        self.put(GAME_OVER, "i", game_over)
        for segment in range(16):
            self.put(WORK + 0x1B4 + segment * 44 + 4, "h", -31500 + segment * 4000)
            self.put(WORK + 0x1B4 + segment * 44 + 40, "i", 12 + segment % 4)

    def run(self, inputs: tuple[int, ...]) -> tuple[int, list[tuple[int, int, int]]]:
        self.prepare(*inputs)
        self.events = []
        self.reached_end = False
        before = self.cpu.mem_read(WORK & 0x1FFFFF, WORK_SIZE)
        self.cpu.reg_write(UC_MIPS_REG_S2, WORK)
        self.cpu.reg_write(UC_MIPS_REG_SP, 0x801FE000)
        self.cpu.emu_start(FINALE_START, 0x801FF800, count=10000)
        if not self.reached_end or self.cpu.reg_read(UC_MIPS_REG_PC) != FINALE_END:
            raise RuntimeError("Original finale did not reach its continuation")
        after = self.cpu.mem_read(WORK & 0x1FFFFF, WORK_SIZE)
        if before[:0xC80] != after[:0xC80]:
            raise RuntimeError(
                "Original finale unexpectedly changed another actor field"
            )
        return struct.unpack_from("<i", after, 0xC80)[0], self.events.copy()


def format_fixture(
    inputs: tuple[int, ...], timer: int, events: list[tuple[int, int, int]]
) -> str:
    if len(events) > 2:
        raise ValueError("Fixture trace exceeds the two-call contract")
    fields = ", ".join(map(str, inputs))
    trace = (
        ", ".join("{" + ", ".join(map(str, event)) + "}" for event in events) or "{0}"
    )
    return f"    {{{{{fields}}}, {timer}, {len(events)}, {{{trace}}}}},"


def fixtures(reference: FinaleReference) -> str:
    rows = []
    products = itertools.product(TIMERS, (0, 0x4CF9, 0xFFFF), (0, 1, -2), POSITIONS)
    for index, (timer, procedure, game_over, position) in enumerate(products):
        inputs = (timer, procedure, game_over, index % 16, position)
        actual_timer, events = reference.run(inputs)
        rows.append(format_fixture(inputs, actual_timer, events))
    timeline = []
    timer = 0
    for step in range(74):
        inputs = (timer, 0x4CF9, int(step == 70), 0, 17600)
        timer, events = reference.run(inputs)
        timeline.append(format_fixture(inputs, timer, events))
    return (
        "/* Synthetic traces from Integral s19b/4bbc.b, SHA-256\n"
        f" * {OVERLAY_SHA256}.\n"
        " * Original finale 800CDE24..800CDEE8; original route lookup 800CEDFC.\n"
        " * Calls: 1=fade(mode,ticks), 2=rumble(byte offset,port), 3=GCL(proc,args).\n"
        " * Regenerate with tests/reference_jeep_finale.py and the user's overlay. */\n"
        "static const FinaleFixture finale_fixtures[] = {\n"
        + "\n".join(rows)
        + "\n};\nstatic const FinaleFixture finale_timeline[] = {\n"
        + "\n".join(timeline)
        + "\n};\n"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--overlay", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    arguments = parser.parse_args()
    reference = FinaleReference(arguments.overlay.read_bytes())
    arguments.output.write_text(fixtures(reference), encoding="utf-8")


if __name__ == "__main__":
    main()
