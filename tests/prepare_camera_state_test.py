"""Extract the live album actor submission for its font-page ordering regression."""

import argparse
from pathlib import Path

from prepare_mantis_test import definition

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    source = ROOT / "vendor/mgs/source/overlays/camera/unknown/camera.c"
    actor = definition(source.read_text(encoding="utf-8"), "CameraAct_800CE404")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        actor.replace("Work *work", "CameraWork *work") + "\n", encoding="utf-8"
    )


if __name__ == "__main__":
    main()
