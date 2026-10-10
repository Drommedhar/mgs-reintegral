"""Extract the production footprint eligibility, wetness and actor update code."""

import argparse
from pathlib import Path

from prepare_mantis_test import definition

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--original-eager-read", action="store_true")
    args = parser.parse_args()
    source = (ROOT / "vendor/mgs/source/enemy/asiato.c").read_text(encoding="utf-8")
    start = source.index("typedef struct _Work2")
    end = source.index("} Work2;", start) + len("} Work2;")
    snippets = [source[start:end]]
    for name in (
        "asiato_800D16F8",
        "AsiatoIsAllowedOnMove_800D179C",
        "asiato_800D17BC",
        "RecordAsiatoPosition",
        "Act",
    ):
        body = definition(source, name)
        if args.original_eager_read and name == "asiato_800D17BC":
            if body.count("#ifdef MGS_NATIVE") != 1:
                raise ValueError("Expected one native eligibility guard")
            body = body.replace("#ifdef MGS_NATIVE", "#if 0")
        snippets.append(body)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n\n".join(snippets) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
