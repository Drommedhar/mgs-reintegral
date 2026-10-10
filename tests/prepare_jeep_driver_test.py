"""Extract the live jeep gate and road-event state machines for reference tests."""

import argparse
from pathlib import Path

from prepare_mantis_test import definition

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    source = (
        ROOT / "vendor/mgs/source/overlays/s19b/takabe/jeep_mrl/jeep_mrl.c"
    ).read_text(encoding="utf-8")
    names = (
        "s19b_jeep_mrl_800D2CE8",
        "s19b_jeep_mrl_800D2E78",
        "GateApproach",
        "GateTireSmoke",
        "GateBrake",
        "EscapeState_800D2F54",
        "GateTurn",
        "GateAccelerate",
        "EscapeState_800D32C4",
        "s19b_jeep_mrl_800D36A4",
        "s19b_jeep_mrl_800D37D0",
        "s19b_jeep_mrl_800D3928",
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        "\n\n".join(definition(source, name) for name in names) + "\n", encoding="utf-8"
    )


if __name__ == "__main__":
    main()
