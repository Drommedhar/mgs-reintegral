"""Select unchanged recovered Hind flight routines for original-MIPS comparisons."""

import argparse
from pathlib import Path

from prepare_mantis_test import definition

ROOT = Path(__file__).resolve().parent.parent
GROUPS = {
    "hindbody.c": ("s11g_hind_800D61F8", "s11g_hind_800D62BC"),
    "hindbody2.c": ("s11g_hind_800D96B0", "s11g_hind_800D9B80", "s11g_hind_800DA534"),
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    snippets = []
    folder = ROOT / "vendor/mgs/source/overlays/s11g/kojo"
    for filename, names in GROUPS.items():
        text = (folder / filename).read_text(encoding="utf-8")
        snippets.extend(definition(text, name) for name in names)
    demo = (folder.parent / "okajima/11g_demo.c").read_text(encoding="utf-8")
    start = demo.index("typedef struct _Work")
    end = demo.index("} Work;", start) + len("} Work;")
    snippets.append(demo[start:end])
    snippets.append(definition(demo, "s11g_11g_demo_800CB878"))
    for relative, work, names in (
        ("takabe/puthzd.c", "PutHzdWork", ("PutHzdTranslatePoint", "PutHzdTranslate")),
        ("kojo/inverlt.c", "InverseLightWork", ("InverseLightVertex",)),
    ):
        text = (ROOT / "vendor/mgs/source" / relative).read_text(encoding="utf-8")
        start = text.index("typedef struct")
        end = text.index("} " + work + ";", start) + len("} " + work + ";")
        snippets.append(text[start:end])
        snippets.extend(definition(text, name) for name in names)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n\n".join(snippets) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
