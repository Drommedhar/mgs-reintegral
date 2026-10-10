"""Extract the live underwater packet generation and allocation lifecycle."""

import argparse
from pathlib import Path

from prepare_mantis_test import definition

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    source = ROOT / "vendor/mgs/source/takabe/wt_view.c"
    text = source.read_text(encoding="utf-8")
    declarations = text[
        text.index("typedef DR_STP") : text.index("static void SetupSprites1")
    ]
    names = [
        "SetupSprites1",
        "SetupSprites2",
        "CheckInBounds",
        "Act",
        "Die",
        "WaterViewCreatePrims",
        "WaterViewInitSinTable",
        "WaterViewDraw",
    ]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        declarations + "\n\n".join(definition(text, name) for name in names) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
