"""Extract prison and elevator commander guard retirement and sorting functions."""

import argparse
from pathlib import Path

from prepare_mantis_test import definition

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    source = ROOT / "vendor/mgs/source/overlays/s03d/animal/zako/zakocom.c"
    text = source.read_text(encoding="utf-8")
    names = ("ZakoCom_800D4050", "s03d_800D47BC")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        "\n\n".join(definition(text, name) for name in names) + "\n",
        encoding="utf-8",
    )
    source = ROOT / "vendor/mgs/source/animal/zako11e/zk11ecom.c"
    text = source.read_text(encoding="utf-8")
    names = ("s11e_zk11ecom_800D9A20", "s11e_zk11ecom_800D9A64", "s11e_zk11ecom_800DA16C")
    args.output.with_name("s11e_commander_helpers.inc").write_text(
        "\n\n".join(definition(text, name) for name in names) + "\n",
        encoding="utf-8",
    )
    source = ROOT / "vendor/mgs/source/animal/zako14/zako14com.c"
    text = source.read_text(encoding="utf-8")
    names = ("ZAKO14SetWorkID", "ZAKO14ResetWorkID", "ChangePrio")
    args.output.with_name("s14e_commander_helpers.inc").write_text(
        "\n\n".join(definition(text, name) for name in names) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
