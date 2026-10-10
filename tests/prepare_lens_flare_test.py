"""Extract unchanged native lens-flare routines for original-MIPS fixtures."""

import argparse
from pathlib import Path

from prepare_mantis_test import definition

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    text = (ROOT / "vendor/mgs/source/okajima/lens_fl.c").read_text(encoding="utf-8")
    start = text.index("typedef struct")
    end = text.index("} LensFlareWork;") + len("} LensFlareWork;")
    snippets = [
        text[start:end],
        "static DVECTOR LensFlareProject(LensFlareWork *work);",
    ]
    snippets.extend(
        definition(text, name)
        for name in (
            "LensFlarePacket",
            "LensFlareVertex",
            "LensFlareAct",
            "LensFlareFreePrims",
            "LensFlareDie",
        )
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n\n".join(snippets) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
