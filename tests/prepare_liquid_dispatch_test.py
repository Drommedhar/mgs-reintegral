"""Extract the real Liquid dispatcher and adjacent target/physics routines."""

import argparse
from pathlib import Path

from prepare_mantis_test import definition


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    output = parser.parse_args().output
    root = Path(__file__).resolve().parent.parent / "vendor/mgs/source"
    groups = {
        "animal/liquid/liquid_action.c": (
            "liquid_800CC1F0",
            "liquid_800CC278",
            "liquid_800CC2A0",
        ),
        "libgv/near.c": ("NearExp2", "GV_NearExp2"),
    }
    snippets = []
    for relative, names in groups.items():
        text = (root / relative).read_text(encoding="utf-8")
        snippets.extend(definition(text, name) for name in names)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n\n".join(snippets) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
