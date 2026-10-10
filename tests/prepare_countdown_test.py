"""Extract the actual countdown renderer and its data for packet comparisons."""

import argparse
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    source = root / "vendor/mgs/source/overlays/s19b/menu/countdwn.c"
    text = source.read_text(encoding="utf-8")
    end = text.index(
        '#else\n#pragma INCLUDE_ASM("asm/overlays/s19b/s19b_countdwn_800C3C90.s")'
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(text[:end] + "#endif\n", encoding="utf-8")


if __name__ == "__main__":
    main()
