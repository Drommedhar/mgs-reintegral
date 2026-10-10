"""Summarize host frame timing and compare aligned native input replay samples."""

import argparse
import csv
import json
import math
from array import array
from collections import defaultdict
from pathlib import Path


def samples(path: Path):
    with path.open(newline="", encoding="utf-8-sig") as stream:
        reader = csv.DictReader(stream)
        for row in reader:
            if None in row or any(value is None for value in row.values()):
                raise ValueError(
                    f"Incomplete timing row in {path}, line {reader.line_num}"
                )
            for field in ("vsync", "game_tick", "frame_us", "draw_us"):
                if not math.isfinite(float(row[field])):
                    raise ValueError(
                        f"Invalid {field} in {path}, line {reader.line_num}"
                    )
            yield row


def percentile(values: list[float], fraction: float) -> float:
    return values[max(0, math.ceil(len(values) * fraction) - 1)]


def summarize(path: Path) -> dict:
    timings = defaultdict(lambda: array("d"))
    stalls = defaultdict(int)
    empty_refills = defaultdict(int)
    previous_empty = 0
    worst = []
    count = 0
    for row in samples(path):
        count += 1
        stage = row["stage"] or "startup"
        milliseconds = float(row["frame_us"]) / 1000
        timings[stage].append(milliseconds)
        target = float(row.get("target_us", 1000000 / 59.94))
        stalls[stage] += float(row["frame_us"]) > target + 2000
        empty = int(row.get("audio_empty_refills", 0))
        empty_refills[stage] += empty - previous_empty
        previous_empty = empty
        worst.append(
            {
                key: row[key]
                for key in (
                    "vsync",
                    "input_sample",
                    "stage",
                    "game_tick",
                    "applied_frame",
                    "frame_us",
                    "draw_us",
                    "submit_us",
                    "audio_queued_frames",
                    "audio_empty_refills",
                )
                if key in row
            }
        )
        worst.sort(key=lambda item: float(item["frame_us"]), reverse=True)
        del worst[10:]
    stages = {}
    for stage, values in timings.items():
        ordered = sorted(values)
        average = sum(values) / len(values)
        stages[stage] = {
            "logged_samples": len(values),
            "logged_average_ms": average,
            "logged_p99_ms": percentile(ordered, 0.99),
            "max_ms": ordered[-1],
            "over_budget_plus_2ms": stalls[stage],
            "audio_empty_refill_counter_increase": empty_refills[stage],
        }
    return {
        "path": str(path),
        "logged_samples": count,
        "stages": stages,
        "worst_frames": worst,
        "note": "Default logs contain slow frames only; averages and percentiles describe logged frames, not the entire run. Audio counter increases can include unlogged intervals.",
    }


def compare(reference: Path, replay: Path) -> dict:
    matched = mismatched = reference_only = replay_only = slower = 0
    examples = []
    first, second = iter(samples(reference)), iter(samples(replay))
    original, repeated = next(first, None), next(second, None)
    while original is not None or repeated is not None:
        if repeated is None or (
            original is not None and int(original["vsync"]) < int(repeated["vsync"])
        ):
            reference_only += 1
            original = next(first, None)
            continue
        if original is None or int(repeated["vsync"]) < int(original["vsync"]):
            replay_only += 1
            repeated = next(second, None)
            continue
        fields = ("vsync", "stage", "game_tick", "input_sample")
        differences = [
            field for field in fields if original.get(field) != repeated.get(field)
        ]
        if differences:
            mismatched += 1
            if len(examples) < 10:
                examples.append({"vsync": original["vsync"], "fields": differences})
        else:
            matched += 1
            slower += float(repeated["frame_us"]) - float(original["frame_us"]) > 5000
        original, repeated = next(first, None), next(second, None)
    return {
        "aligned_samples": matched,
        "mismatched_samples": mismatched,
        "reference_only_logged_frames": reference_only,
        "replay_only_logged_frames": replay_only,
        "alignment_errors": examples,
        "aligned_frames_over_5ms_slower": slower,
        "note": "Sparse logs are joined by VSync. A missing row can mean a healthy frame or an unfinished run; use the input replay result to verify completion. Wall times are not deterministic assertions. Empty refills are not measured hardware underruns.",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("recording", type=Path)
    parser.add_argument("--compare", type=Path)
    args = parser.parse_args()
    result = {"recording": summarize(args.recording)}
    if args.compare:
        result["replay"] = summarize(args.compare)
        result["comparison"] = compare(args.recording, args.compare)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
