"""Extract the live briefing packet, layout, and screen-effect helpers."""

import argparse
from pathlib import Path

from prepare_mantis_test import definition

ROOT = Path(__file__).resolve().parent.parent
GRAPH = ROOT / "vendor/mgs/source/overlays/brf/onoda/brf"


def source():
    selected = {
        "graph_fog.c": ["BrfSetTexture"],
        "graph_motion.c": ["brf_800CD734", "brf_800CD7DC", "brf_800CDC8C"],
        "graph_render.c": [
            "brf_800DDD78",
            "brf_800DDDE8",
            "brf_800DDE5C",
            "brf_800DE004",
            "brf_800DE0F4",
            "brf_800DE270",
            "brf_800DD7C8",
            "brf_800DD830",
        ],
    }
    parts = []
    for name, functions in selected.items():
        text = (GRAPH / name).read_text(encoding="utf-8")
        parts.extend(definition(text, function) for function in functions)
    for name in ["graph_assets.c", "graph_layout.c", "graph_noise.c"]:
        text = (GRAPH / name).read_text(encoding="utf-8")
        parts.append(
            "\n".join(
                line for line in text.splitlines() if not line.startswith("#include")
            )
        )
    return "\n\n".join(parts) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(source(), encoding="utf-8")


if __name__ == "__main__":
    main()
