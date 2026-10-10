"""Compile actual initialized, tentative and local data in native overlay sections."""

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from tools.native_overlay import write_regions


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    source = Path(__file__).resolve().parent
    actor_a = source / "overlay_actor_a.c"
    actor_b = source / "overlay_actor_b.c"
    args.output.mkdir(parents=True, exist_ok=True)
    prefixes = write_regions(
        args.output / "mgs_overlay_regions.inc",
        {"a": [actor_a], "b": [actor_b], "shared": [actor_a, actor_b]},
        source,
    )
    for path, prefix in prefixes.items():
        (args.output / path.name).write_text(
            prefix + path.read_text(encoding="utf-8"), encoding="utf-8"
        )


if __name__ == "__main__":
    main()
