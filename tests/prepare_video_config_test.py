"""Extract renderer output failure paths for isolated allocation/window tests."""

import argparse
import re
from pathlib import Path

from prepare_mantis_test import definition

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    platform = ROOT / "vendor/psyz/psyz/src/platform"
    snippets = []
    for filename, names in (
        ("sdl3_gpu.c", ("AdjustInternalRes", "ApplyPendingInternalRes")),
        ("sdl3_common.h", ("ApplyRequestedFullscreen", "WaitForNextFrame")),
    ):
        source = (platform / filename).read_text(encoding="utf-8")
        source = re.sub(r"\)\s*\{", ")\n{", source)
        snippets.extend(definition(source, name) for name in names)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n\n".join(snippets) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
