"""Select the live escape road sequence, routing and floor conversion routines."""

import argparse
from pathlib import Path

from prepare_mantis_test import definition

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    folder = ROOT / "vendor/mgs/source/overlays/s19b"
    source = (folder / "takabe/jeep_srl.c").read_text(encoding="utf-8")
    data = (folder / "overlay2.c").read_text(encoding="utf-8")
    start = data.index("short EscapeRoadSequence")
    snippets = [data[start : data.index(";", start) + 1]]
    start = data.index("unsigned char EscapeRoadRumble")
    snippets.append(data[start : data.index(";", start) + 1])
    functions = (
        "s19b_jeep_srl_800CD638",
        "CopyHazardPoint",
        "s19b_jeep_gls_800CE628",
        "RoadIndex",
        "s19b_jeep_gls_800CEDFC",
        "UpdateFinale",
    )
    snippets.extend(definition(source, name) for name in functions)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n\n".join(snippets) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
