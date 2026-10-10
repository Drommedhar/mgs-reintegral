"""Select recovered rappel state helpers for comparisons with original instructions."""

import argparse
from pathlib import Path

from prepare_mantis_test import definition

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    folder = ROOT / "vendor/mgs/source/overlays/s11d/chara/hind"
    source = (folder / "hind.c").read_text(encoding="utf-8")
    native = (folder / "hind_native.h").read_text(encoding="utf-8")
    start = source.index("typedef struct")
    end = source.index("} Work;", start) + len("} Work;")
    snippets = [source[start:end]]
    util = (ROOT / "vendor/mgs/source/libgv/util.c").read_text(encoding="utf-8")
    snippets.append(definition(util, "GV_DiffDirS"))
    for name in ("s11d_hind_800C976C", "s11d_hind_800C9870", "s11d_hind_800C9908"):
        snippets.append(definition(source, name))
    for name in (
        "RappelClamp",
        "s11d_hind_800C99F4",
        "s11d_hind_800C9B94",
        "s11d_hind_800C9C7C",
        "RappelHoverDirection",
        "RappelHoverBegin",
        "RappelHoverEnd",
        "s11d_hind_800C9D60",
        "s11d_hind_800CA504",
        "RappelSweepBegin",
        "s11d_hind_800CA6D8",
        "s11d_hind_800CAFEC",
    ):
        snippets.append(definition(native, name))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n\n".join(snippets) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
