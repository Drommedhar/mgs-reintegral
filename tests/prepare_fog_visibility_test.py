"""Extract live fog bounds and vertex clipping for visibility regressions."""

import argparse
from pathlib import Path

from prepare_mantis_test import definition

ROOT = Path(__file__).resolve().parent.parent


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    source = (ROOT / "vendor/mgs/source/takabe/libdg2.c").read_text(encoding="utf-8")
    functions = ("FogClassicMode", "DG_BoundObjs_800D5010", "FogBoundChanl_800D5500")
    snippets = [definition(source, name) for name in functions]
    start = source.index("#ifdef MGS_NATIVE\n#define FOG_HALF_WIDTH")
    end = source.index("static inline void DG_TransVerticesBound", start)
    snippets.append(source[start:end])
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n\n".join(snippets) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
