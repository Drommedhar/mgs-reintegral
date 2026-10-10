"""Extract Liquid's climb action and the actual two-vector hazard output helper."""

import argparse
from pathlib import Path

from prepare_mantis_test import definition


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    output = parser.parse_args().output
    source = Path(__file__).resolve().parent.parent / "vendor/mgs/source"
    near = (source / "libhzd/near.c").read_text(encoding="utf-8")
    action = (source / "animal/liquid/liquid_action.c").read_text(encoding="utf-8")
    layout = near[near.index("typedef struct") : near.index("static inline int")]
    snippets = [
        layout,
        "#define HZD_GetNearVector OriginalNearVector",
        definition(near, "HZD_GetNearVector"),
        "#undef HZD_GetNearVector",
        "#define HZD_GetNearVector(output) "
        "CheckedNearVector((output), __builtin_object_size((output), 1))",
        definition(action, "liquid_800CBB50"),
        "#undef HZD_GetNearVector",
    ]
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n\n".join(snippets) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
