"""Extract the actual chaff initialization and rectangle packet writer."""

import argparse
import re
from pathlib import Path

from prepare_mantis_test import definition

ROOT = Path(__file__).resolve().parent.parent


def declaration(source: str, pattern: str) -> str:
    match = re.search(pattern, source, re.DOTALL)
    if match is None:
        raise ValueError(f"Cannot locate chaff declaration: {pattern}")
    return match[0]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--original-null-anchor", action="store_true")
    arguments = parser.parse_args()
    chaff = (ROOT / "vendor/mgs/source/okajima/chafgrnd.c").read_text(encoding="utf-8")
    prim = (ROOT / "vendor/mgs/source/libdg/prim.c").read_text(encoding="utf-8")
    table_start = prim.index("typedef struct _DG_PRIM_INFO")
    table_end = prim.index(";", prim.index("SVECTOR DG_ZeroVector")) + 1
    resource = definition(chaff, "GetResources")
    if arguments.original_null_anchor:
        if resource.count("&chaff_particle_anchor") != 1:
            raise ValueError("Expected one native chaff anchor argument")
        resource = resource.replace("&chaff_particle_anchor", "NULL")
    snippets = [
        prim[table_start:table_end],
        definition(prim, "DG_MakePrim"),
        definition(prim, "DG_FreePrim"),
        definition(prim, "_MakeXYZRectangleSingle"),
        declaration(chaff, r"static int SECTION\(\"\.bss\"\) dword_800BDF9C;"),
        declaration(chaff, r"int SECTION\(\"\.bss\"\) okajima_CHAF_LIFE;"),
        declaration(chaff, r"static RECT chaff_particle_anchor\s*=\s*\{[^}]+};"),
        declaration(chaff, r"#define CHAFF_LIFETIME[^\r\n]*"),
        declaration(chaff, r"typedef struct _Work\s*\{.*?} Work;"),
        definition(chaff, "InitParticleSize"),
        definition(chaff, "InitParticleColor"),
        resource,
        definition(chaff, "Die"),
    ]
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text("\n\n".join(snippets) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
