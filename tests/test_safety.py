"""Exercise native image validation using synthetic ISO9660 raw sectors."""

import argparse
import struct
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path

SECTOR_BYTES = 2352
DATA_OFFSET = 24
CUE = 'FILE "disc.bin" BINARY\n TRACK 01 MODE2/2352\n INDEX 01 00:00:00\n'


def both_endian(value: int) -> bytes:
    return struct.pack("<I", value) + struct.pack(">I", value)


def directory_record(name: str, sector: int, size: int, directory=False) -> bytes:
    encoded = name.encode("ascii")
    record = bytearray(33 + len(encoded) + (len(encoded) % 2 == 0))
    record[0] = len(record)
    record[2:10] = both_endian(sector)
    record[10:18] = both_endian(size)
    record[25] = 2 if directory else 0
    record[28:32] = b"\1\0\0\1"
    record[32] = len(encoded)
    record[33 : 33 + len(encoded)] = encoded
    return bytes(record)


def bcd(value: int) -> int:
    return value // 10 * 16 + value % 10


def sector_fixture() -> list[bytearray]:
    sectors = [bytearray(SECTOR_BYTES) for _ in range(23)]
    for index, sector in enumerate(sectors):
        sector[:12] = b"\0" + b"\xff" * 10 + b"\0"
        position = index + 150
        sector[12:16] = bytes(
            [bcd(position // 4500), bcd(position // 75 % 60), bcd(position % 75), 2]
        )
    pvd = sectors[16]
    pvd[24:31] = b"\1CD001\1"
    pvd[104:112] = both_endian(23)
    pvd[152:156] = b"\0\x08\x08\0"
    root = directory_record("\0", 17, 2048, directory=True)
    pvd[180 : 180 + len(root)] = root
    records = {
        17: directory_record("MGS", 18, 2048, directory=True)
        + directory_record("SYSTEM.CNF;1", 19, 64),
        18: directory_record("SLPM_862.47;1", 20, 2048)
        + directory_record("STAGE.DIR;1", 21, 4096),
        19: b"BOOT = cdrom:\\MGS\\SLPM_862.47;1\r\n",
        20: b"PS-X EXE",
        21: struct.pack("<I8sI", 12, b"s00a", 1),
    }
    for index, data in records.items():
        sectors[index][DATA_OFFSET : DATA_OFFSET + len(data)] = data
    return sectors


@dataclass(frozen=True)
class Case:
    name: str
    expected: int
    changes: tuple[tuple[int, int, bytes], ...] = ()
    cue: str = CUE
    trim: int = 0
    location: str = "33"
    second: str = "4"


CASES = [
    Case("valid", 0),
    Case("disc-change-volume", 0, location="22", second="2"),
    Case("wrong-volume-location", 3, location="23", second="2"),
    Case("bad-volume-stage-table", 3, ((21, 24, b"\x0d"),), location="22", second="2"),
    Case("wrong-location", 3, location="34"),
    Case("bad-pvd-endian", 2, ((16, 108, b"\x16"),)),
    Case("zero-volume-size", 2, ((16, 104, b"\0" * 8),)),
    Case("root-not-directory", 2, ((16, 205, b"\0"),)),
    Case("wrong-executable", 2, ((20, 24, b"\0"),)),
    Case("bad-sector-address", 3, ((21, 14, b"\0"),)),
    Case("bad-xa-copy", 3, ((21, 16, b"\1"),)),
    Case("form2-stage", 3, ((21, 18, b"\x20"), (21, 22, b"\x20"))),
    Case("bad-table-size", 3, ((21, 24, b"\x0d"),)),
    Case("bad-stage-name", 3, ((21, 28, b"S"),)),
    Case("bad-stage-extent", 3, ((21, 36, b"\x07"),)),
    Case("missing-executable", 2, ((18, 57, b"X"),)),
    Case("unsupported-serial", 2, ((19, 51, b"9"),)),
    Case("truncated-image", 2, trim=13),
    Case("multitrack-cue", 2, cue=CUE + " TRACK 02 AUDIO\n INDEX 01 00:00:00\n"),
    Case("mode1-cue", 2, cue=CUE.replace("MODE2", "MODE1")),
    Case("external-bin-path", 2, cue=CUE.replace("disc.bin", "../disc.bin")),
]


def run_case(probe: Path, directory: Path, case: Case) -> None:
    directory.mkdir()
    sectors = sector_fixture()
    for sector, offset, data in case.changes:
        sectors[sector][offset : offset + len(data)] = data
    binary = b"".join(sectors)
    if case.trim:
        binary = binary[: -case.trim]
    (directory / "disc.bin").write_bytes(binary)
    cue_path = directory / "disc.cue"
    cue_path.write_text(case.cue, encoding="ascii")
    result = subprocess.run(
        [str(probe), str(cue_path), "0", case.second, case.location],
        capture_output=True,
        text=True,
        timeout=10,
        check=False,
    )
    if result.returncode != case.expected:
        raise AssertionError(
            f"{case.name}: expected {case.expected}, got {result.returncode}\n"
            f"{result.stdout}{result.stderr}"
        )
    print(f"PASS {case.name}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("probe", type=Path)
    arguments = parser.parse_args()
    probe = arguments.probe.resolve(strict=True)
    with tempfile.TemporaryDirectory(prefix="mgs-safety-") as temporary:
        for case in CASES:
            run_case(probe, Path(temporary) / case.name, case)
    print(f"{len(CASES)} native disc validation cases passed")


if __name__ == "__main__":
    main()
