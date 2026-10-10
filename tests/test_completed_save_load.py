"""Load a real completed-mission save through the original menus using SDL input."""

import argparse
import hashlib
import json
import shutil
import struct
import subprocess
import zlib
from pathlib import Path


def inspect_save(path: Path, ending: str) -> dict:
    data = path.read_bytes()
    if len(data) != 8192 or data[:4] != b"SC\x11\x01":
        raise ValueError("Expected an original one-block game save")
    size, checksum = struct.unpack_from("<II", data, 256)
    payload = data[264 : 256 + size]
    if size != 0xA40 or zlib.crc32(payload) != checksum:
        raise ValueError("Save size or CRC is invalid")
    if struct.unpack_from("<II", payload) != (0x60, 0x800):
        raise ValueError("Expected the recovered Integral save version")
    words = struct.unpack_from("<96h", payload, 56)
    story = struct.unpack_from("<h", payload, 248 + 10)[0]
    stage = payload[24:40].split(b"\0", 1)[0].decode("ascii")
    expected = (1, 1, -1) if ending == "meryl" else (2, -1, 1)
    if (words[3], words[48], words[47]) != expected:
        raise ValueError("Save does not contain the requested ending's earned item")
    if (words[0], words[1], words[6], story, stage) != (1, 1, 0, 0, "rank"):
        raise ValueError("Expected a fresh Normal completed-game save from ranking")
    return {
        "source": str(path),
        "sha256": hashlib.sha256(data).hexdigest(),
        "ending": ending,
        "completions": words[0],
        "difficulty": words[1],
        "clear": words[3],
        "bandana": words[48],
        "stealth": words[47],
        "stage": stage,
        "story": story,
        "crc_valid": True,
    }


def build_command(args: argparse.Namespace, output: Path, identity: str) -> list[str]:
    command = [
        str(args.exe),
        "--disc",
        str(args.disc),
        "--probe",
        "completed-load",
        "--frames",
        "4000",
        "--capture",
        str(output / "loaded.bmp"),
        "--record-input",
        str(output / "load.mgsinput"),
        "--input-identity",
        identity,
    ]
    if args.debugger:
        script = output / "fast-render.cdb"
        script.write_text(
            "bu /1 mgs_integral_native!mgs_main "
            '"ed mgs_integral_native!vsync_mode 3; gc"\n'
            'sxe -c "r;kv;q" av\nsxe -c "r;kv;q" dz\ng\nq\n',
            encoding="ascii",
        )
        command = [str(args.debugger), "-o", "-G", "-cf", str(script), *command]
    return command


def verify_transcript(transcript: str, info: dict) -> None:
    stages = [
        line.split("stage=", 1)[1]
        for line in transcript.splitlines()
        if line.startswith("[native] stage=")
    ]
    if stages != ["init", "title", "abst", "d00a", "s00a"]:
        raise AssertionError(f"Unexpected original stage sequence: {stages}")
    expected = (
        "[completed-load] PASS loaded=1 valid=1 stages=4/4 movement=1 "
        f"preserved=1 completions=1 clear={info['clear']} "
        f"bandana={info['bandana']} stealth={info['stealth']}."
    )
    if expected not in transcript:
        raise AssertionError(
            "Completed-save acceptance, inventory or movement was not verified"
        )


def run(args: argparse.Namespace) -> None:
    info = inspect_save(args.save, args.ending)
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    runtime = output / "runtime"
    (runtime / "bu00").mkdir(parents=True)
    (runtime / "bu10").mkdir()
    copied = runtime / "bu00" / args.save.name
    shutil.copyfile(args.save, copied)
    identity = hashlib.sha256(json.dumps(info, sort_keys=True).encode()).hexdigest()
    info["input_identity"] = identity
    info["executable"] = str(args.exe)
    info["executable_sha256"] = hashlib.sha256(args.exe.read_bytes()).hexdigest()
    command = build_command(args, output, identity)
    (output / "manifest.json").write_text(
        json.dumps(info, indent=2) + "\n", encoding="utf-8"
    )
    try:
        with (output / "load.log").open("w", encoding="utf-8") as log:
            subprocess.run(
                command,
                cwd=runtime,
                stdout=log,
                stderr=subprocess.STDOUT,
                check=True,
                timeout=150,
            )
        transcript = (output / "load.log").read_text(encoding="utf-8")
        verify_transcript(transcript, info)
    finally:
        for candidate in (args.save, copied):
            if hashlib.sha256(candidate.read_bytes()).hexdigest() != info["sha256"]:
                raise AssertionError(
                    f"Load-only scenario changed save bytes: {candidate}"
                )
    print(
        f"{args.ending}: original completed save loaded; earned item, new round and movement PASS"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--exe", type=Path, required=True)
    parser.add_argument("--disc", type=Path, required=True)
    parser.add_argument("--save", type=Path, required=True)
    parser.add_argument("--ending", choices=("meryl", "otacon"), required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument(
        "--debugger",
        type=Path,
        help="Optional x86 CDB: uncap rendering; no game-state writes",
    )
    args = parser.parse_args()
    for key in ("exe", "disc", "save", "debugger"):
        value = getattr(args, key)
        if value is not None:
            setattr(args, key, value.resolve(strict=True))
    run(args)


if __name__ == "__main__":
    main()
