"""Select recovered Ninja helpers for comparisons with original MIPS execution."""

import argparse
import re
from pathlib import Path

from prepare_mantis_test import definition

ROOT = Path(__file__).resolve().parent.parent
NINJA = ROOT / "vendor/mgs/source/overlays/s08b/animal/ninja"
GROUPS = {
    "ninja.c": [
        "s08b_bunsin2_800CEF94",
        "s08b_bunsin2_800CEFC0",
        "s08b_bunsin2_800CE064",
        "s08b_bunsin2_800CE9BC",
        "s08b_bunsin2_800D0530",
        "s08b_bunsin2_800D06A0",
        "s08b_bunsin2_800CFA80",
        "s08b_bunsin2_800D1738",
        "s08b_bunsin2_800D2158",
        "s08b_bunsin2_800D2DB0",
    ],
    "ninja_native_actions.h": ["s08b_bunsin2_800C9BF8"],
    "ninja_native_combat.h": [
        "s08b_bunsin2_800CEFF4",
        "s08b_bunsin2_800CF354",
        "s08b_bunsin2_800CF464",
        "s08b_bunsin2_800CF54C",
    ],
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    data = (NINJA / "ninja_native_data.h").read_text(encoding="utf-8")
    table = re.search(
        r"signed char s08b_ninja_zones\[20\]\[4\] = .*?;", data, re.DOTALL
    )
    if table is None:
        raise ValueError("Cannot locate the original Ninja route table")
    snippets = [table[0]]
    for name in ("s08b_dword_800C3454", "s08b_ninja_positions", "s08b_dword_800C34F8"):
        declaration = re.search(
            r"^(?:int|SVECTOR)\s+" + name + r"(?:\[[^\]]*\])?\s*=.*?;",
            data,
            re.MULTILINE | re.DOTALL,
        )
        if declaration is None:
            raise ValueError(f"Cannot locate Ninja terminal data: {name}")
        snippets.append(declaration[0])
    snippets.append("#define s08b_dword_800C3458 s08b_ninja_positions[0]")
    for relative, names in GROUPS.items():
        source = (NINJA / relative).read_text(encoding="utf-8")
        snippets.extend(definition(source, name) for name in names)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n\n".join(snippets) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
