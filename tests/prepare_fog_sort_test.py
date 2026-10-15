"""Extract the live fog sorter for Godot ownership and ordering checks."""

import argparse
from pathlib import Path

from prepare_mantis_test import definition


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    source = (root / "vendor/mgs/source/takabe/libdg2.c").read_text(encoding="utf-8")
    source = source.replace(
        "void (*callback)(void *, void *, int)", "FogCallbackType callback"
    )
    start = source.index("typedef struct _SCRATCHPAD_UNK")
    end = source.index("} SCRATCHPAD_UNK;", start) + len("} SCRATCHPAD_UNK;")
    snippets = [
        "typedef void (*FogCallbackType)(void *, void *, int);",
        source[start:end],
    ]
    snippets.extend(
        definition(source, name)
        for name in ("get_scratch", "s12c_800D4CF4", "s12c_800D4D8C")
    )
    snippets.append(
        "#ifdef MGS_GODOT_SCENE\n"
        + definition(source, "GodotFogSortPrims")
        + "\n#endif"
    )
    snippets.append(definition(source, "FogSortChanl_800D4E98"))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n\n".join(snippets) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
