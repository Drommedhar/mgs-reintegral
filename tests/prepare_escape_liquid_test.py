"""Extract the live escape gunner and vehicle helpers for retail MIPS comparisons."""

import argparse
from pathlib import Path

from prepare_mantis_test import definition

ROOT = Path(__file__).resolve().parent.parent
GROUPS = {
    "jeep_liq_actor_native.h": (
        "s19b_spark2_m_800D87A4",
        "s19b_spark2_m_800D9148",
        "s19b_spark2_m_800D9680",
    ),
    "jeep_collision_native.h": ("s19b_spark2_m_800DA0B4", "s19b_spark2_m_800D9C90"),
    "jeep_liq_vehicle_native.h": ("s19b_jeep_liq_800D771C",),
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    directory = ROOT / "vendor/mgs/source/overlays/s19b/takabe/jeep_liq"
    snippets = []
    for filename, names in GROUPS.items():
        source = (directory / filename).read_text(encoding="utf-8")
        snippets.extend(definition(source, name) for name in names)
    vector_source = (ROOT / "vendor/mgs/source/libgv/util.c").read_text(
        encoding="utf-8"
    )
    snippets.extend(
        definition(vector_source, name)
        for name in ("GV_AddVec3", "GV_SubVec3", "GV_LenVec3")
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n\n".join(snippets) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
