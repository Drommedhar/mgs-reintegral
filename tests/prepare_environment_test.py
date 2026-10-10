"""Select the actual environment-mapping functions for native packet checks."""

import argparse
import re
from pathlib import Path

from prepare_mantis_test import definition

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    directory = ROOT / "vendor/mgs/source/takabe"
    environment = (directory / "envmap3.c").read_text(encoding="utf-8")
    submarine = (directory / "sub_efct.c").read_text(encoding="utf-8")
    scratch = re.search(
        r"typedef struct _Envmap3Scratch.*?} Envmap3Scratch;", environment, re.DOTALL
    )
    if scratch is None:
        raise ValueError("Cannot locate the environment-map scratch layout")
    snippets = [scratch[0]]
    for source, names in [
        (environment, ["Envmap3_800C9F14", "Envmap3_800C9FF4"]),
        (submarine, ["SubEfct_800CC798", "SubEfct_800CC860"]),
    ]:
        snippets.extend(definition(source, name) for name in names)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n\n".join(snippets) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
