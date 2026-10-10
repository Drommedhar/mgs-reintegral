"""Summarize recorded demo update intervals without changing playback."""

import argparse
import csv
import json
from collections import Counter
from pathlib import Path


def camera(row: dict[str, str]) -> tuple[int, ...]:
    return tuple(
        int(row[field])
        for field in (
            "camera_x",
            "camera_y",
            "camera_z",
            "target_x",
            "target_y",
            "target_z",
        )
    )


def interval(previous: dict[str, str], current: dict[str, str], paused: int) -> dict:
    return {
        "from_vsync": int(previous["vsync"]),
        "to_vsync": int(current["vsync"]),
        "vsyncs": int(current["vsync"]) - int(previous["vsync"]),
        "elapsed_ms": (int(current["elapsed_us"]) - int(previous["elapsed_us"])) / 1000,
        "desired_delta": int(current["desired_frame"]) - int(previous["desired_frame"]),
        "applied_delta": int(current["applied_frame"]) - int(previous["applied_frame"]),
        "updates": int(current["applied_count"]) - int(previous["applied_count"]),
        "camera_changed": camera(previous) != camera(current),
        "paused_samples": paused,
        "frame_divisor": int(current["frame_divisor"]),
    }


def summarize(rows: list[dict[str, str]]) -> dict:
    updates = []
    previous = None
    paused = 0
    for row in rows:
        paused += int(row["pause"]) != 0
        if previous is None:
            previous = row
        elif row["applied_count"] != previous["applied_count"]:
            updates.append(interval(previous, row, paused))
            previous, paused = row, 0
    tail = interval(previous, rows[-1], paused) if previous else None
    return {
        "stage": rows[0]["stage"],
        "demo_id": int(rows[0]["demo_id"]),
        "demo_total": int(rows[0]["demo_total"]),
        "first_applied": int(rows[0]["applied_frame"]),
        "last_applied": int(rows[-1]["applied_frame"]),
        "applied_count": int(rows[-1]["applied_count"]),
        "samples": len(rows),
        "observed_duration_seconds": (
            int(rows[-1]["elapsed_us"]) - int(rows[0]["elapsed_us"])
        )
        / 1000000,
        "update_vsync_histogram": dict(
            sorted(Counter(entry["vsyncs"] for entry in updates).items())
        ),
        "frame_divisors": dict(Counter(int(row["frame_divisor"]) for row in rows)),
        "maximum_update_interval_ms": max(
            (entry["elapsed_ms"] for entry in updates), default=0
        ),
        "intervals_over_250ms": sum(entry["elapsed_ms"] > 250 for entry in updates),
        "unpaused_intervals_over_250ms": sum(
            entry["elapsed_ms"] > 250 and not entry["paused_samples"]
            for entry in updates
        ),
        "largest_intervals": sorted(
            updates, key=lambda entry: entry["elapsed_ms"], reverse=True
        )[:10],
        "unfinished_tail": tail,
    }


def analyze(path: Path) -> dict:
    groups: dict[tuple[str, str], list[dict[str, str]]] = {}
    samples = 0
    with path.open(newline="", encoding="utf-8") as stream:
        for row in csv.DictReader(stream):
            samples += 1
            if row["demo_active"] == "1" and int(row["applied_count"]) > 0:
                groups.setdefault((row["stage"], row["demo_id"]), []).append(row)
    return {"samples": samples, "demos": [summarize(rows) for rows in groups.values()]}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("csv", type=Path)
    args = parser.parse_args()
    print(json.dumps(analyze(args.csv), indent=2))


if __name__ == "__main__":
    main()
