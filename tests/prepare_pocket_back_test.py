"""Extract live PocketStation background helpers for original-instruction fixtures."""

import argparse
from pathlib import Path

from prepare_mantis_test import definition

ROOT = Path(__file__).resolve().parent.parent
POCKET = ROOT / "vendor/mgs/source/overlays/rank/chara/pocket"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    entry = (POCKET / "entry.c").read_text(encoding="utf-8")
    source = (POCKET / "pkt_back.c").read_text(encoding="utf-8")
    pieces = [
        definition(entry, name)
        for name in ("rank_800D1C10", "PocketTexture", "rank_800D1C44")
    ]
    names = (
        "rank_800CEE0C",
        "rank_800CEE90",
        "rank_800CEF28",
        "rank_800CEF5C",
        "rank_800CF11C",
        "rank_800CF160",
        "rank_800CF1D4",
        "rank_800CF1F4",
        "rank_800CF288",
        "rank_800CF2F0",
        "rank_800CF328",
        "rank_800CF36C",
        "rank_800CF3A0",
        "rank_800CF3C8",
        "PocketBackColor",
        "rank_800CF3FC",
        "PocketBackTiles",
        "rank_800CF938",
        "rank_800CFBD8",
        "rank_800CFD00",
        "rank_800CFF1C",
        "rank_800D007C",
        "rank_800D0258",
        "rank_800D03E8",
        "rank_800D04A8",
        "rank_800D0648",
    )
    for name in names:
        snippet = definition(source, name)
        if name in ("rank_800CEF5C", "rank_800CFBD8"):
            snippet = snippet.replace(name, name + "_actual", 1)
        pieces.append(snippet)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n\n".join(pieces) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
