"""Select recovered rappel physics without replacing their integer calculations."""

import argparse
from pathlib import Path

from prepare_mantis_test import definition

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    folder = ROOT / "vendor/mgs/source/overlays/s11d/chara/rope"
    text = (folder / "rope.c").read_text(encoding="utf-8")
    start = text.index("typedef struct")
    end = text.index("} Work;", start) + len("} Work;")
    snippets = [text[start:end]]
    groups = {
        "rope_native_motion.h": (
            "s11d_rope_800C4B78",
            "s11d_rope_800C5584",
            "s11d_rope_800C634C",
        ),
        "rope_native_setup.h": ("s11d_rope_800C5E74",),
    }
    for filename, functions in groups.items():
        source = (folder / filename).read_text(encoding="utf-8")
        snippets.extend(definition(source, name) for name in functions)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n\n".join(snippets) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
