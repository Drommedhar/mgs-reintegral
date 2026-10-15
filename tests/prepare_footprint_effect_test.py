"""Extract the three native footprint actors' visual construction and fade paths."""

import argparse
from pathlib import Path

from prepare_mantis_test import definition

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    for name, prefix in [("asiato", "AsiatoChar_"), ("asiato2", "Asiato2Char_"), ("demoasi", "")]:
        source = (ROOT / f"vendor/mgs/source/enemy/{name}.c").read_text(encoding="utf-8")
        start = source.index("typedef struct _Work\n")
        end = source.index("} Work;", start) + len("} Work;")
        snippets = [source[start:end]]
        for function in ["ShadePacks", "SetPos", "InitPacks", "GetResources", "Act"]:
            snippets.append(definition(source, prefix + function))
        (args.output / f"{name}_effect.inc").write_text("\n\n".join(snippets) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
