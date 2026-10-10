"""Select the live escape Snake recovery for original-MIPS fixture comparisons."""

import argparse
from pathlib import Path

from prepare_mantis_test import definition

ROOT = Path(__file__).resolve().parent.parent
FUNCTIONS = (
    "s19b_jeep_sne_800D47F8",
    "s19b_jlamp2_800D50F4",
    "s19b_jlamp2_800D519C",
    "EscapeSnakeAxis",
    "EscapeSnakeInput",
    "s19b_jlamp2_800D596C",
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    source = (
        ROOT / "vendor/mgs/source/overlays/s19b/takabe/jeep_sne/jeep_sne.c"
    ).read_text(encoding="utf-8")
    start = source.index("typedef struct _Work")
    end = source.index("} Work;", start) + len("} Work;")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.with_name("escape_snake_types.inc").write_text(
        source[start:end], encoding="utf-8"
    )
    args.output.write_text(
        "\n\n".join(definition(source, name) for name in FUNCTIONS) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
