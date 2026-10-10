"""Extract the Tank gunner target consumers and production layouts."""

import argparse
from pathlib import Path

from prepare_mantis_test import definition


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    output = parser.parse_args().output
    root = Path(__file__).resolve().parent.parent
    source = (root / "vendor/mgs/source/overlays/s05a/kojo/m1e1sold.c").read_text(encoding="utf-8")
    declarations = source[source.index("typedef struct") : source.index("typedef struct _Sol")]
    names = ("s05a_800DF834", "s05a_800DF9C8", "s05a_800E00EC")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(declarations + "\nCamActor *s05a_dword_800C362C;\n" +
                      "\n\n".join(definition(source, name) for name in names), encoding="utf-8")


if __name__ == "__main__":
    main()
