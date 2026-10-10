"""Select unchanged Raven navigation routines for original-MIPS comparisons."""

import argparse
from pathlib import Path

from prepare_mantis_test import definition

ROOT = Path(__file__).resolve().parent.parent
FUNCTIONS = (
    "Valcan_800DA1AC",
    "Valcan_800DAE38",
    "s15c_crow_800DA2A8",
    "s15c_crow_800DAE7C",
    "s15c_crow_800DAFCC",
    "s15c_crow_800DB200",
    "s15c_crow_800DD03C",
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    source = ROOT / "vendor/mgs/source/overlays/s15c/okajima/valcan/valcan.c"
    text = source.read_text(encoding="utf-8")
    snippets = [definition(text, name) for name in FUNCTIONS]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n\n".join(snippets) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
