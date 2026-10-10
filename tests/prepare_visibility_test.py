"""Extract production bounds and render-scope code for gameplay visibility tests."""

import argparse
from pathlib import Path

from prepare_mantis_test import definition

ROOT = Path(__file__).resolve().parent.parent
FUNCTIONS = {
    "bound.c": (
        "BoundCheckDepth",
        "BoundCheckWidth",
        "BoundCheck",
        "BoundObjsNative",
        "DG_BoundChanl",
    ),
    "chanl.c": ("DG_SortChanlSystem",),
}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    snippets = []
    for filename, names in FUNCTIONS.items():
        path = ROOT / "vendor/mgs/source/libdg" / filename
        source = path.read_text(encoding="utf-8")
        snippets.extend(definition(source, name) for name in names)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n\n".join(snippets) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
