"""Extract live smoke scripts, descriptors and spawners without changing qualifiers."""

import argparse
import re
from pathlib import Path
from prepare_mantis_test import definition

ROOT = Path(__file__).resolve().parent.parent
GROUPS = (
    ("socom.c", "AN_Unknown_800D70E4", "anim_data_800CC1CC"),
    ("smoke3.c", "AN_Unknown_800DC6AC", "s13a_dword_800E3280"),
    ("smoke_ln.c", "AN_Smoke_800CE2C4", "d16e_dword_800D2BF8"),
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument(
        "--old-const", action="store_true", help="Private pre-fix crash reproduction"
    )
    args = parser.parse_args()
    output = []
    for file, function, script in GROUPS:
        source = (ROOT / "vendor/mgs/source/anime/effect" / file).read_text(
            encoding="utf-8"
        )
        declarations = re.findall(
            r"static\s+(?:const\s+)?(?:char|ANIMATION)\s+\w+(?:\[\])?\s*=\s*\{.*?\};",
            source,
            re.S,
        )
        text = "\n".join(declarations)
        if args.old_const:
            text = text.replace(
                f"static char {script}[]", f"static const char {script}[]"
            )
            text = re.sub(
                r"(?m)^(\s*)" + script + r"(\s*(?://[^\n]*)?\n)",
                r"\1(char *)" + script + r"\2",
                text,
            )
        output.extend((text, definition(source, function)))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n\n".join(output), encoding="utf-8")


if __name__ == "__main__":
    main()
