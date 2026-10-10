"""Extract the live renderer clipping functions for viewport boundary tests."""

import argparse
from pathlib import Path

from prepare_mantis_test import definition

ROOT = Path(__file__).resolve().parent.parent
FUNCTIONS = {
    "bound.c": ("BoundCheckDepth", "BoundCheckWidth", "BoundCheck"),
    "trans.c": ("DG_BoundCheck",),
    "divide.c": ("DG_SetRVectorCode",),
    "frame.c": ("DG_Clip",),
}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    snippets = []
    for filename, names in FUNCTIONS.items():
        source = ROOT / "vendor/mgs/source/libdg" / filename
        text = source.read_text(encoding="utf-8")
        snippets.extend(definition(text, name) for name in names)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n\n".join(snippets) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
