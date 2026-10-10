"""Extract unchanged recovered tower cinematic code for original-MIPS fixtures."""

import argparse
from pathlib import Path

from prepare_mantis_test import definition

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    source = ROOT / "vendor/mgs/source/overlays/s11b/okajima/11b_demo.c"
    text = source.read_text(encoding="utf-8")
    start = text.index("typedef struct")
    end = text.index("} Stage11BWork;") + len("} Stage11BWork;")
    snippets = [text[start:end]]
    snippets.extend(
        "static " + declaration + ";"
        for declaration in (
            "int Stage11BInitPrim(Stage11BWork *work)",
            "void Stage11BDebris(Stage11BWork *work)",
            "void Stage11BUpdatePackets(Stage11BWork *work)",
            "void Stage11BCamera(Stage11BWork *work)",
        )
    )
    snippets.extend(
        definition(text, name)
        for name in (
            "Stage11BInterpolate",
            "Stage11BSound",
            "Stage11BRibbon",
            "Stage11BAdvanceCamera",
            "Stage11BAct",
            "Stage11BInitDebris",
            "Stage11BGetResources",
        )
    )
    smoke = (ROOT / "vendor/mgs/source/okajima/crsh_smk.c").read_text(encoding="utf-8")
    start = smoke.index("typedef struct")
    end = smoke.index("} CrashSmokeWork;") + len("} CrashSmokeWork;")
    snippets.append(smoke[start:end])
    snippets.append(definition(smoke, "CrashSmokeAct"))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n\n".join(snippets) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
