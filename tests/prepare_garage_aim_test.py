"""Extract the live garage aim-matrix block and complete bullet constructor helper."""

import argparse
from pathlib import Path

from prepare_mantis_test import definition

ROOT = Path(__file__).resolve().parent.parent


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    source = (ROOT / "vendor/mgs/source/overlays/s19a/props_snake.c").read_text(
        encoding="utf-8"
    )
    controller = definition(source, "Garage_800DAE40")
    start = controller.index("    mov = GarageGunOffset;")
    end = controller.index("    *GarageGunWorld = work->field_8E4;")
    end += len("    *GarageGunWorld = work->field_8E4;")
    block = "static void BuildAim(GarageSnake *work)\n{\n    SVECTOR mov;\n    MATRIX right;\n"
    block += controller[start:end] + "\n}\n"
    position = (ROOT / "vendor/mgs/source/libdg/pos.c").read_text(encoding="utf-8")
    snippets = [
        definition(position, name)
        for name in ("DG_SetPos", "DG_SetPos2", "DG_PutVector", "DG_RotVector")
    ]
    snippets.extend((block, definition(source, "Garage_800DA8A0")))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n\n".join(snippets) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
