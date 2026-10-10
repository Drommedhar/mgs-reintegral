"""Select unchanged recovered helper definitions for isolated reference tests."""

import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GROUPS = {
    "libgv/util.c": ["GV_DiffDirS"],
    "overlays/s07b/chara/meryl07b/meryl07b.c": [
        "s07b_800C46F0",
        "s07b_800C4974",
        "s07b_800C54C0",
        "s07b_800C54E8",
        "s07b_800C5514",
        "s07b_800C5554",
    ],
    "overlays/s07b/chara/psyco/psyco.c": [
        "s07b_800CBDA0",
        "s07b_800CC9E8",
        "s07b_800CCA10",
        "s07b_800CCA80",
        "s07b_800CCBB0",
        "s07b_800CC174",
    ],
}


def definition(text, name):
    match = re.search(
        r"^[A-Za-z_][A-Za-z_0-9 \t*]*\b" + re.escape(name) + r"\([^)]*\)\s*\n\{",
        text,
        re.MULTILINE,
    )
    if match is None:
        raise ValueError(f"Cannot locate function definition: {name}")
    end = match.end()
    depth = 1
    while depth and end < len(text):
        depth += (text[end] == "{") - (text[end] == "}")
        end += 1
    if depth:
        raise ValueError(f"Unclosed function: {name}")
    return text[match.start() : end]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    snippets = []
    for relative, names in GROUPS.items():
        source = ROOT / "vendor/mgs/source" / relative
        text = source.read_text(encoding="utf-8")
        snippets.extend(definition(text, name) for name in names)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n\n".join(snippets) + "\n", encoding="utf-8")
    memory = (ROOT / "vendor/mgs/source/chara/psyco/mempsy.c").read_text(encoding="utf-8")
    table_start = memory.index("#define GENRE_OTHER")
    table_end = memory.index("};", memory.index("#endif // INTEGRAL")) + 2
    thresholds = re.search(r"static char s07b_dword_800C3738\[\][\s\S]*?\};", memory)
    if thresholds is None:
        raise ValueError("Missing memory-card dialogue thresholds")
    snippets = ["typedef struct { const char *name; int mask; } SAVEFILE;",
                thresholds.group(), memory[table_start:table_end]]
    snippets.extend(definition(memory, name) for name in
                    ("s07b_800D8338", "s07b_800D8410", "NativeMemoryProfile"))
    args.output.with_name("mantis_memory.inc").write_text("\n\n".join(snippets) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
