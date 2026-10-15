"""Extract actual XA decoder helpers for synthetic CPU regression."""

import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    source = (ROOT / "vendor/psyz/psyz/src/psyz/libcd.c").read_text(encoding="utf-8")
    clamp = source[
        source.index("static short clamp16(") : source.index("// Trim whitespace")
    ]
    state = source[
        source.index("static struct {\n    short decoded[") : source.index(
            "static void xa_reset_stream"
        )
    ]
    helpers = source[
        source.index("static int s4(") : source.index(
            "static int xa_read_and_decode_sector"
        )
    ]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        "#define XA_DECODED_MAX_FRAMES 4032\n" + clamp + state + helpers,
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
