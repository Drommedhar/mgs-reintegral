"""Extract the selected Tank actor layout and completion callback unchanged."""

import argparse
from pathlib import Path

from prepare_mantis_test import definition

ROOT = Path(__file__).resolve().parent.parent


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    arguments = parser.parse_args()
    source = (ROOT / "vendor/mgs/source/overlays/s05a/kojo/m1e1act.c").read_text(
        encoding="utf-8"
    )
    declarations = source[source.index("typedef struct") : source.index("extern int")]
    body = definition(source, "s05a_800D5E30")
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text(declarations + "\n" + body + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
