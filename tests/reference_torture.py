"""Compare torture round handoffs with privately extracted Integral instructions."""

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

from reference_boss_terminal import REGISTERS, STATUS, STOP, WORK, Reference, hash_bytes

PAD, MESSAGES = 0x80181000, 0x80181100
FUNCTIONS = (0x800C5AF8, 0x800C3EB8, 0x800C4314)
COUNTS = (1536, 768, 128)
TICKS = (-1, 0, 1, 2, 65535, 65536)
HEALTH = (-32768, -1, 0, 1, 511, 512, 32760, 32767)


def initial_work(seed: int) -> bytearray:
    data = bytearray((i * 37 + seed * 11 + 3) & 255 for i in range(0x904))
    words = {
        0x808: 0x12345678,
        0x80C: 79,
        0x810: TICKS[seed % 6],
        0x834: PAD,
        0x840: (-1, 0, 0x7FFF)[seed // 6 % 3],
    }
    halves = {
        0xAA: 6 if seed & 1 else 2,
        0x800: (0, 4, 0x8000, 0xFFFF)[seed // 2 % 4],
        0x802: (0, 2, 0x8000, 0xFFFF)[seed // 8 % 4],
        0x804: HEALTH[seed // 6 % 8],
        0x818: seed // 32 % 2,
        0x81A: (0, 1, 2, 32767)[seed // 64 % 4],
        0x84A: (1, 3, 256, 65535)[seed // 48 % 4],
        0x84C: (0, 1, 2, 65535)[seed // 192 % 4],
        0x85C: seed // 256 % 3,
        0x85E: 2,
    }
    for offset, value in words.items():
        struct.pack_into("<I", data, offset, value & 0xFFFFFFFF)
    for offset, value in halves.items():
        struct.pack_into("<H", data, offset, value & 0xFFFF)
    # This suite observes the completion message through the real queue reader.
    data[0x76] = seed % 3
    struct.pack_into("<I", data, 0x7C, MESSAGES)
    return data


class TortureReference(Reference):
    def hook(self, cpu: Uc, address: int, size: int, context: object) -> None:
        del size, context
        handlers = {
            0x80034CD4: 0,
            0x8001FF2C: 1,
            0x80017090: 2,
            0x800C447C: 3,
            0x800C95EC: 4,
            0x800CA5D0: 5,
        }
        if address not in handlers:
            return
        kind = handlers[address]
        args = [cpu.reg_read(reg) for reg in REGISTERS]
        self.event(kind)
        result = 0
        if kind == 0:
            self.event(args[0] - WORK, *args[1:])
        elif kind == 1:
            count = struct.unpack("<H", self.read(args[1], 2))[0]
            self.event(args[0], count, self.word(self.word(args[1] + 4)))
            if self.seed // 768:
                self.cpu.mem_write((WORK + 0x802) & 0x1FFFFF, b"\x02\x00")
        elif kind == 2:
            self.event(args[0])
        elif kind == 3:
            if args[0] != WORK:
                raise ValueError("Torture message helper received the wrong actor")
            self.event(*args[1:3])
        elif kind == 4:
            result = self.seed // 512 % 2
            self.event(result)
        else:
            self.event(self.word(STATUS))
        cpu.reg_write(UC_MIPS_REG_V0, result)
        cpu.reg_write(UC_MIPS_REG_PC, cpu.reg_read(UC_MIPS_REG_RA))

    def run_torture(self, kind: int, seed: int) -> tuple[int, int, int, int]:
        self.seed, self.trace = seed, []
        cpu = self.cpu
        cpu.mem_write(0, bytes(0x200000))
        load = struct.unpack_from("<I", self.image, 24)[0] & 0x1FFFFF
        cpu.mem_write(load, self.image[2048:])
        cpu.mem_write(WORK & 0x1FFFFF, bytes(initial_work(seed)))
        cpu.mem_write(PAD & 0x1FFFFF, struct.pack("<HH", 0, 0x120 if seed & 1 else 0))
        messages = bytearray(40)
        struct.pack_into("<H", messages, 4, 4 if seed & 1 else 3)
        struct.pack_into("<H", messages, 24, 4 if seed & 2 else 3)
        cpu.mem_write(MESSAGES & 0x1FFFFF, bytes(messages))
        cpu.mem_write(0xB4DB0, struct.pack("<h", 512))
        self.put(STATUS, 0x12563478)
        cpu.reg_write(UC_MIPS_REG_A0, WORK)
        cpu.reg_write(UC_MIPS_REG_A1, TICKS[seed % 6] & 0xFFFFFFFF)
        cpu.reg_write(UC_MIPS_REG_SP, 0x801FE800)
        cpu.reg_write(UC_MIPS_REG_RA, STOP)
        cpu.emu_start(FUNCTIONS[kind], STOP, count=10000)
        if cpu.reg_read(UC_MIPS_REG_PC) != STOP:
            raise RuntimeError("Torture routine exceeded its instruction budget")
        state = self.read(WORK, 0x904) + self.read(STATUS, 4)
        trace = struct.pack(f"<{len(self.trace)}I", *self.trace)
        result = cpu.reg_read(UC_MIPS_REG_V0) if kind == 2 else 0
        return hash_bytes(state), hash_bytes(trace), len(self.trace), result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    image = args.image.read_bytes()
    reference = TortureReference(image)
    lines = [
        f"/* Private combined image SHA256: {hashlib.sha256(image).hexdigest()} */",
        "static const TortureFixture torture_fixtures[] = {",
    ]
    for kind, count in enumerate(COUNTS):
        for seed in range(count):
            state, trace, words, result = reference.run_torture(kind, seed)
            lines.append(
                f"    {{{kind}, {seed}, 0x{state:08x}u, 0x{trace:08x}u, {words}, {result}}},"
            )
    lines.append("};")
    args.output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Generated {sum(COUNTS)} original-MIPS torture comparisons.")


if __name__ == "__main__":
    main()
