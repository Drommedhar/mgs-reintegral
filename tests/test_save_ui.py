"""Test original save/load menus using an explicit story-1 hangar scenario fixture."""

import argparse
import struct
import subprocess
import tempfile
import zlib
from pathlib import Path


def run_probe(
    executable: Path, debugger: Path, disc: Path, runtime: Path, output: Path, mode: str
) -> None:
    saving = mode == "save-menu"
    label = "save" if saving else "load"
    command = [
        str(executable),
        "--disc",
        str(disc),
        "--stage",
        "s02a" if saving else "title",
        "--probe",
        mode,
        "--frames",
        "2400" if saving else "6000",
        "--capture",
        str(output / f"{label}.bmp"),
    ]
    if saving:
        script = runtime / "story-fixture.cdb"
        script.write_text(
            'bu mgs_integral_native!GCL_SaveVar ".if '
            "(poi(mgs_integral_native!GM_CurrentStageName)==0x61323073) { "
            ".echo [save-fixture] story variable 0x1100000A = 1 before snapshot; "
            'ew mgs_integral_native!var_buf+0xa 1; }; gc"\ng\nq\n',
            encoding="ascii",
        )
        command = [
            str(debugger),
            "-G",
            "-y",
            str(executable.parent),
            "-cf",
            str(script),
            *command,
        ]
    with (output / f"{label}.log").open("w", encoding="utf-8") as log:
        subprocess.run(
            command,
            cwd=runtime,
            stdout=log,
            stderr=subprocess.STDOUT,
            check=True,
            timeout=150,
        )
    transcript = (output / f"{label}.log").read_text(encoding="utf-8")
    assert "[probe] PASS completed automated input probe" in transcript
    if not saving:
        loaded = [
            line
            for line in transcript.splitlines()
            if line.startswith("[native] stage=")
        ]
        assert loaded == [
            f"[native] stage={stage}" for stage in ("init", "title", "abst", "s02a")
        ]


def validate_save(runtime: Path) -> None:
    files = list((runtime / "bu00").iterdir())
    assert len(files) == 1, "Original save menu must create exactly one file"
    data = files[0].read_bytes()
    assert len(files[0].name) == 20
    assert len(data) == 8192 and data[:4] == b"SC\x11\x01"
    size, checksum = struct.unpack_from("<II", data, 256)
    assert size == 0xA40
    payload = data[264 : 256 + size]
    assert struct.unpack_from("<II", payload) == (0x60, 0x800)
    assert payload[24:40].rstrip(b"\0") == b"s02a"
    assert struct.unpack_from("<H", payload, 56 + 12)[0] == 0x46DB
    assert struct.unpack_from("<H", payload, 248 + 10)[0] == 1
    assert zlib.crc32(payload) == checksum


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--exe", type=Path, required=True)
    parser.add_argument("--debugger", type=Path, required=True)
    parser.add_argument("--disc", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    executable = args.exe.resolve(strict=True)
    debugger = args.debugger.resolve(strict=True)
    disc = args.disc.resolve(strict=True)
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="mgs-save-ui-") as directory:
        runtime = Path(directory)
        run_probe(executable, debugger, disc, runtime, output, "save-menu")
        validate_save(runtime)
        run_probe(executable, debugger, disc, runtime, output, "load-menu")
    print(
        "Story-1 fixture: original save, CRC, restart, saved-area load, and movement passed."
    )


if __name__ == "__main__":
    main()
