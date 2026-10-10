"""Select the live PocketStation packing and selector functions for reference tests."""

import argparse
from pathlib import Path

from prepare_mantis_test import definition

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    folder = ROOT / "vendor/mgs/source/overlays/rank/menu"
    groups = {
        "pocket_card.c": (
            "PocketReadWord",
            "PocketWriteWord",
            "PocketEncodeCharacter",
            "PocketDecodeCharacter",
            "rank_800CBD14",
            "rank_800CC3D4",
        ),
        "pocket_ui.c": ("rank_800CDCF4",),
    }
    snippets = []
    for file, names in groups.items():
        source = (folder / file).read_text(encoding="utf-8")
        snippets.extend(definition(source, name) for name in names)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n\n".join(snippets) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
