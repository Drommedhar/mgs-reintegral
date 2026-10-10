"""Extract live PocketStation glyph, cursor, input, and node helpers."""

import argparse
from pathlib import Path

from prepare_mantis_test import definition
from prepare_pocket_entry_test import DATA, ENTRY, table


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    source = ENTRY.read_text(encoding="utf-8")
    names = (
        "PocketPacket",
        "rank_800D0E4C",
        "PocketGlyph",
        "rank_800D0ECC",
        "rank_800D1218",
        "rank_800D1230",
        "rank_800D128C",
        "rank_800D12D0",
        "rank_800D2144",
        "rank_800D2188",
        "rank_800D23F0",
        "rank_800D23F8",
        "rank_800D2428",
        "rank_800D2458",
        "rank_800D2544",
        "rank_800D2574",
        "rank_800D2644",
        "rank_800D1AF4",
        "rank_800D1B78",
        "rank_800D1C10",
        "rank_800D20B0",
    )
    pieces = [table(DATA.read_text(encoding="utf-8"), "PocketPunctuation")]
    pieces.extend(definition(source, name) for name in names)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n\n".join(pieces) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
