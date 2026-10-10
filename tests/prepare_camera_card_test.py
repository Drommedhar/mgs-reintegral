"""Extract the live camera card worker and writer for original-instruction tests."""

import argparse
from pathlib import Path

from prepare_mantis_test import definition

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    source = ROOT / "vendor/mgs/source/overlays/camera/unknown/camera_card.c"
    text = source.read_text(encoding="utf-8")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    snippets = [
        definition(text, "camera_800C4D70"),
        definition(text, "CameraSaveFilename"),
    ]
    snippets.append(
        definition(text, "camera_800C4790").replace(
            "camera_800C4790(", "CameraWriteActual(", 1
        )
    )
    args.output.write_text("\n\n".join(snippets) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
