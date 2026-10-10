"""Extract the actual item destructor for native callback dispatch checks."""

import argparse
from pathlib import Path

from prepare_mantis_test import definition

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    source = (ROOT / "vendor/mgs/source/game/item.c").read_text(encoding="utf-8")
    start = source.index("typedef struct _Work")
    end = source.index("} Work;", start) + len("} Work;")
    snippets = [source[start:end], definition(source, "Die")]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n\n".join(snippets) + "\n", encoding="utf-8")
    source = (ROOT / "vendor/mgs/source/chara/torture/boxall.c").read_text(encoding="utf-8")
    start = source.index("typedef struct _BoxallWork")
    end = source.index("} Work;", start) + len("} Work;")
    snippets = [source[start:end]]
    snippets.extend(definition(source, name) for name in
                    ("GetWorldPosition", "DrawItemText", "HasCollectedItem"))
    args.output.with_name("boxall_helpers.inc").write_text(
        "\n\n".join(snippets) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
