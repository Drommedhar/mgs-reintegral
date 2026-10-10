"""Extract the claymore trajectory helper and its original actor layout."""

import argparse
from pathlib import Path

from prepare_mantis_test import definition

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    source = ROOT / "vendor/mgs/source"
    text = (source / "okajima/claymore.c").read_text(encoding="utf-8")
    vectors = (source / "libgv/util.c").read_text(encoding="utf-8")
    snippets = [
        text[text.index("typedef struct _Work") : text.index("/*---", text.index("} Work;"))],
        "static MAP *claymore_MAP_800bdf08;",
        text[text.index("STATIC SVECTOR stru_8009F650") : text.index("STATIC SVECTOR stru_8009F660")],
        definition(vectors, "GV_SubVec3"),
        "#define DG_PutVector(from, to, count) "
        "CheckedPutVector((from), (to), (count), __builtin_object_size((to), 1))",
        definition(text, "claymore_loader_helper_800735A0"),
        "#undef DG_PutVector",
    ]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n\n".join(snippets) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
