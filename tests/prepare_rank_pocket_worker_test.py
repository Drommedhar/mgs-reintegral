"""Select the live PocketStation transfer worker for original-MIPS fixtures."""

import argparse
from pathlib import Path

from prepare_mantis_test import definition

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    source = (ROOT / "vendor/mgs/source/overlays/rank/menu/pocket_task.c").read_text(
        encoding="utf-8"
    )
    names = (
        "PocketDetectPorts",
        "PocketWaitForPort",
        "PocketFinishTransfer",
        "rank_800CC798",
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        "\n\n".join(definition(source, name) for name in names) + "\n", encoding="utf-8"
    )


if __name__ == "__main__":
    main()
