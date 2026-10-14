"""Extract production fog shading and thermal-palette updates for scene tests."""

import argparse
from pathlib import Path

from prepare_mantis_test import definition

ROOT = Path(__file__).resolve().parent.parent
FUNCTIONS = {
    "libdg/bound.c": ("SetThermalClut", "RestoreThermalClut", "UpdateThermalTexture"),
    "takabe/libdg2.c": (
        "s12c_800D497C",
        "s12c_800D59CC",
        "s12c_800D5A34",
        "s12c_800D5B00",
        "FogShadeChanl_800D6A04",
    ),
}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    snippets = []
    for filename, names in FUNCTIONS.items():
        source = (ROOT / "vendor/mgs/source" / filename).read_text(encoding="utf-8")
        snippets.extend(definition(source, name) for name in names)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n\n".join(snippets) + "\n", encoding="utf-8")
    trans = (ROOT / "vendor/mgs/source/libdg/trans.c").read_text(encoding="utf-8")
    shade = (ROOT / "vendor/mgs/source/libdg/shade.c").read_text(encoding="utf-8")
    fog = (ROOT / "vendor/mgs/source/takabe/libdg2.c").read_text(encoding="utf-8")
    start = trans.index("typedef struct _SCRATCH")
    end = trans.index("#define SPAD", start)
    links = [trans[start:end]]
    for source, names in (
        (trans, ("DG_WriteObjVerticesIndirect", "DG_TransChanl")),
        (shade, ("DG_ShadePacksIndirect", "DG_ShadeChanl")),
        (fog, ("s12c_800D5CDC", "FogTransChanl_800D63B0", "s12c_800D67F0")),
    ):
        links.extend(definition(source, name) for name in names)
    args.output.with_name("scene_links_helpers.inc").write_text(
        "\n\n".join(links) + "\n", encoding="utf-8"
    )


if __name__ == "__main__":
    main()
