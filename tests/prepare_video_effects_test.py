"""Extract live framebuffer-effect packet builders for ordering regressions."""

import argparse
import re
from pathlib import Path

from prepare_mantis_test import definition

ROOT = Path(__file__).resolve().parent.parent
EFFECTS = (
    (
        "takabe/wt_view.c",
        (
            "SetupSprites1",
            "SetupSprites2",
            "WaterViewCreatePrims",
            "WaterViewDraw",
            "CheckInBounds",
            "Act",
        ),
    ),
    ("okajima/blur.c", ("BG_Clear", "InitPacks", "Act")),
    ("okajima/blurpure.c", ("ClearScreen", "InitPrims", "DrawEffect", "Act")),
    ("takabe/focus.c", ("FocusGetResources_800CEDA4", "FocusAct_800CEA70")),
)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    snippets = []
    for index, (filename, functions) in enumerate(EFFECTS):
        source = (ROOT / "vendor/mgs/source" / filename).read_text(encoding="utf-8")
        snippets.append(f"#if MGS_EFFECT == {index}")
        snippets.extend(re.findall(r"typedef\s+struct\b.*?}\s*\w+;", source, re.DOTALL))
        if index == 0:
            snippets.append("static short wt_view_sin_table[32];")
        elif index == 1:
            snippets.append(
                source[
                    source.index("TILE   SECTION") : source.index(
                        "static void BG_Clear"
                    )
                ]
            )
        snippets.extend(definition(source, name) for name in functions)
        snippets.append("#endif")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n\n".join(snippets) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
