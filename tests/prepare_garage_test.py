"""Select live garage companion and parked-Snake state routines for MIPS comparisons."""

import argparse
from pathlib import Path

from prepare_mantis_test import definition

ROOT = Path(__file__).resolve().parent.parent
COMPANION = (
    "800DB950",
    "800DBA10",
    "800DBA54",
    "800DBB44",
    "800DBC28",
    "800DBCF8",
    "800DBD6C",
    "800DBDE4",
    "800DBE58",
    "800DBECC",
    "800DBF44",
    "800DBFB8",
    "800DC028",
    "800DC0A0",
)
SNAKE = (
    "800DA798",
    "800DA840",
    "800DA940",
    "800DAA9C",
    "800DABF0",
    "800DACF4",
    "800DAD68",
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    folder = ROOT / "vendor/mgs/source/overlays/s19a"
    snippets = []
    for name, functions in (("companion", COMPANION), ("snake", SNAKE)):
        source = (folder / f"props_{name}.c").read_text(encoding="utf-8")
        snippets.extend(
            definition(source, "Garage_" + address) for address in functions
        )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n\n".join(snippets) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
