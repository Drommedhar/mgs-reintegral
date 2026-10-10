"""Extract complete boss terminal routines without replacing their behavior."""

import argparse
from pathlib import Path

from prepare_mantis_test import definition


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    output = parser.parse_args().output
    source = Path(__file__).resolve().parent.parent / "vendor/mgs/source"
    groups = {
        "kojo/mgrex.c": ("RexFunc_800DEBB4", "RexFunc_800DB268", "RexFunc_800DB478"),
        "animal/liquid/liquid_tactics.c": ("liquid_800CE6B4",),
        "libgv/near.c": ("NearExp8", "GV_NearExp8"),
    }
    snippets = []
    for relative, names in groups.items():
        text = (source / relative).read_text(encoding="utf-8")
        snippets.extend(definition(text, name) for name in names)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n\n".join(snippets) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
