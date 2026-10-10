"""Derive a verified-prefix endpoint at the latest loaded campaign stage.

This prepares input data only. It neither restores a save nor proves that an
incomplete source recording finished successfully.
"""

import argparse
import hashlib
import io
import json
import re
from dataclasses import dataclass, field
from pathlib import Path

KINDS = {65, 83, 115, 255}
UINT_MAX = (1 << 32) - 1
CAMPAIGN_STAGE = re.compile(r"[sd][0-9]{2}[a-z][a-z0-9_]*\Z")
STAGE = re.compile(r"(?:-|[A-Za-z0-9_]{1,15})\Z")
IDENTITY = re.compile(r"MGSINPUT 1 ([0-9a-f]{64})\Z")


@dataclass(frozen=True)
class Record:
    kind: str
    sample: int
    vsync: int
    kinds: tuple[int, int]
    pads: tuple[str, str]
    stage: str
    state: tuple[int, ...]


@dataclass
class Visit:
    stage: str
    start_sample: int
    boundary: Record | None = None
    end_offset: int = 0


@dataclass
class Inspection:
    identity: str
    complete_samples: int = 0
    has_footer: bool = False
    partial_bytes: int = 0
    last: Record | None = None
    visits: list[Visit] = field(default_factory=list)


def integer(text: str, signed: bool = False) -> int:
    pattern = r"-?[0-9]+" if signed else r"[0-9]+"
    if not re.fullmatch(pattern, text):
        raise ValueError("Invalid decimal input field")
    value = int(text)
    low, high = (-(1 << 31), (1 << 31) - 1) if signed else (0, UINT_MAX)
    if not low <= value <= high:
        raise ValueError("Input integer outside its 32-bit range")
    return value


def validate_field(index: int, token: str, partial: bool = False) -> None:
    if index == 0:
        valid = token in ("P", "E")
    elif 1 <= index <= 4:
        value = integer(token)
        valid = index < 3 or value in KINDS
        if partial and index >= 3:
            valid = any(str(kind).startswith(token) for kind in KINDS)
    elif index in (5, 6):
        length = r"{1,68}" if partial else r"{68}"
        valid = re.fullmatch("[0-9a-f]" + length, token) is not None
    elif index == 7:
        valid = STAGE.fullmatch(token) is not None
    else:
        if partial and token == "-":
            return
        integer(token, signed=True)
        valid = True
    if not valid:
        raise ValueError(f"Invalid input field {index}")


def tokens_for(line: bytes) -> list[str]:
    if b"\0" in line:
        raise ValueError("NUL in input line")
    try:
        text = line.removesuffix(b"\n").removesuffix(b"\r").decode("ascii")
    except UnicodeDecodeError as error:
        raise ValueError("Non-ASCII input line") from error
    return [token for token in text.split(" ") if token]


def parse_record(line: bytes, count: int, last_vsync: int) -> Record:
    tokens = tokens_for(line)
    if len(tokens) != 30:
        raise ValueError("Input record must contain exactly 30 fields")
    for index, token in enumerate(tokens):
        validate_field(index, token)
    record = Record(
        tokens[0],
        int(tokens[1]),
        int(tokens[2]),
        (int(tokens[3]), int(tokens[4])),
        (tokens[5], tokens[6]),
        tokens[7],
        tuple(map(int, tokens[8:])),
    )
    if record.sample != count or record.vsync < last_vsync:
        raise ValueError("Input sample sequence or VSync order mismatch")
    if record.kind == "P" and count == UINT_MAX:
        raise ValueError("Input sample count overflow")
    return record


def validate_partial(line: bytes, count: int, last_vsync: int) -> None:
    tokens = tokens_for(line)
    if not tokens or len(tokens) > 30:
        raise ValueError("Invalid truncated trailing record")
    unfinished = not line.endswith((b" ", b"\r"))
    for index, token in enumerate(tokens):
        validate_field(index, token, unfinished and index == len(tokens) - 1)
    completed = len(tokens) - int(unfinished)
    if completed > 1 and int(tokens[1]) != count:
        raise ValueError("Truncated record has an invalid sample index")
    if completed > 2 and int(tokens[2]) < last_vsync:
        raise ValueError("Truncated record moves VSync backwards")


def observe_visit(scan: Inspection, record: Record, offset: int) -> None:
    previous = scan.last
    new_visit = previous is None or record.stage != previous.stage
    reloading = (
        previous is not None
        and scan.visits[-1].boundary is not None
        and previous.state[1] == 1
        and record.state[1] == 0
    )
    if new_visit or reloading:
        scan.visits.append(Visit(record.stage, record.sample))
    visit = scan.visits[-1]
    ready = record.state[1:4] == (1, 0, 0)
    if ready and visit.boundary is None and CAMPAIGN_STAGE.fullmatch(record.stage):
        visit.boundary = record
        visit.end_offset = offset


def read_line(stream: io.BytesIO) -> bytes:
    line = stream.readline(513)
    if len(line) > 512 or (len(line) == 512 and not line.endswith(b"\n")):
        raise ValueError("Input line exceeds the native parser's 511-byte limit")
    return line


def inspect_data(data: bytes) -> Inspection:
    stream = io.BytesIO(data)
    header = read_line(stream)
    if not header.endswith(b"\n"):
        raise ValueError("Missing complete MGSINPUT header")
    try:
        match = IDENTITY.fullmatch(
            header.removesuffix(b"\n").removesuffix(b"\r").decode("ascii")
        )
    except UnicodeDecodeError as error:
        raise ValueError("Non-ASCII input header") from error
    if match is None:
        raise ValueError("Expected MGSINPUT 1 with a lowercase SHA-256 identity")
    scan = Inspection(match[1])
    last_vsync = 0
    while line := read_line(stream):
        if scan.has_footer:
            raise ValueError("Trailing data after the input footer")
        if not line.endswith(b"\n"):
            validate_partial(line, scan.complete_samples, last_vsync)
            scan.partial_bytes = len(line)
            break
        record = parse_record(line, scan.complete_samples, last_vsync)
        last_vsync = record.vsync
        if record.kind == "E":
            scan.has_footer = True
        else:
            observe_visit(scan, record, stream.tell())
            scan.complete_samples += 1
            scan.last = record
    return scan


def selected_visit(scan: Inspection) -> Visit:
    for visit in reversed(scan.visits):
        if visit.boundary is not None:
            return visit
    raise ValueError("No fully loaded, unpaused campaign stage in complete input rows")


def footer(boundary: Record) -> bytes:
    if boundary.sample == UINT_MAX or boundary.vsync == UINT_MAX:
        raise ValueError("Derived endpoint would overflow the native input counters")
    fields = [
        "E",
        str(boundary.sample + 1),
        str(boundary.vsync + 1),
        "255",
        "255",
        *boundary.pads,
        boundary.stage,
        *map(str, boundary.state),
    ]
    return (" ".join(fields) + "\n").encode("ascii")


def output_paths(source: Path, output: Path, manifest: Path) -> None:
    session = Path(str(source) + ".session").resolve()
    targets = [output.resolve(), manifest.resolve()]
    if targets[0] == targets[1]:
        raise ValueError("Prefix and manifest must use different paths")
    for target in targets:
        if target == source or target.exists() or target.is_symlink():
            raise ValueError(f"Output already exists or aliases the source: {target}")
        if target == session or session in target.parents:
            raise ValueError("Outputs cannot modify the source recording's session")


def make_manifest(
    source: Path,
    output: Path,
    data: bytes,
    prefix: bytes,
    scan: Inspection,
    visit: Visit,
) -> dict:
    boundary = visit.boundary
    if boundary is None or scan.last is None:
        raise ValueError("Missing selected input boundary")
    fell_back = visit is not scan.visits[-1]
    return {
        "schema": "mgs-input-resume-1",
        "source": {
            "path": str(source),
            "sha256": hashlib.sha256(data).hexdigest(),
            "identity": scan.identity,
            "complete_samples": scan.complete_samples,
            "has_footer": scan.has_footer,
            "partial_bytes": scan.partial_bytes,
            "last_stage": scan.last.stage,
            "last_sample": scan.last.sample,
            "last_vsync": scan.last.vsync,
        },
        "selected": {
            "stage": visit.stage,
            "visit_start_sample": visit.start_sample,
            "sample": boundary.sample,
            "vsync": boundary.vsync,
        },
        "prefix": {
            "path": str(output),
            "sha256": hashlib.sha256(prefix).hexdigest(),
            "samples": boundary.sample + 1,
            "endpoint_vsync": boundary.vsync + 1,
        },
        "fallback": {
            "used": fell_back,
            "reason": "The final stage visit has no eligible loaded campaign boundary."
            if fell_back
            else None,
        },
        "derived_endpoint": True,
        "source_completion_verified": False,
        "readiness_policy": "Campaign sNN*/dNN*: load complete=1, load request=0, pause=0; "
        "earliest complete P in the latest qualifying stage visit.",
        "endpoint_policy": "Include selected P; E uses sample+1 and VSync+1 with identical "
        "state and disconnected controller kinds. Pad polling precedes "
        "OnVSync, with no game actors between them.",
        "limitations": "Replaying this derived endpoint verifies only the prefix. Loading "
        "flags do not prove a safe gameplay save point; this is not a save "
        "or process snapshot. Source session data must still match.",
    }


def write_outputs(output: Path, prefix: bytes, manifest: Path, metadata: dict) -> None:
    created = []
    try:
        with output.open("xb") as movie:
            created.append(output)
            with manifest.open("x", encoding="utf-8", newline="\n") as report:
                created.append(manifest)
                movie.write(prefix)
                json.dump(metadata, report, indent=2)
                report.write("\n")
    except (OSError, ValueError):
        for path in reversed(created):
            path.unlink()
        raise


def prepare_input_resume(
    source: Path, output: Path, manifest: Path | None = None
) -> dict:
    source = source.resolve(strict=True)
    output = output.absolute()
    manifest = (
        manifest.absolute()
        if manifest is not None
        else Path(str(output) + ".resume.json")
    )
    output_paths(source, output, manifest)
    data = source.read_bytes()
    scan = inspect_data(data)
    visit = selected_visit(scan)
    if visit.boundary is None:
        raise ValueError("Missing selected input boundary")
    prefix = data[: visit.end_offset] + footer(visit.boundary)
    metadata = make_manifest(source, output, data, prefix, scan, visit)
    write_outputs(output, prefix, manifest, metadata)
    return metadata


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--manifest", type=Path)
    arguments = parser.parse_args()
    try:
        metadata = prepare_input_resume(
            arguments.source, arguments.output, arguments.manifest
        )
    except (OSError, ValueError) as error:
        parser.exit(2, f"Cannot prepare input resume: {error}\n")
    print(json.dumps(metadata, indent=2))


if __name__ == "__main__":
    main()
