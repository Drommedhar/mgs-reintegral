"""Extract the panorama and vignette packet builders for coverage checks."""

import argparse
import re
from pathlib import Path

from prepare_mantis_test import definition

ROOT = Path(__file__).resolve().parent.parent / "vendor/mgs/source"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    snippets = []
    for index, name in enumerate(("thing/sphere.c", "thing/sphere2.c", "takabe/gas_efct.c")):
        source = (ROOT / name).read_text(encoding="utf-8")
        snippets.append(f"#if MGS_ENVIRONMENT == {index}")
        snippets.extend(re.findall(r"typedef\s+struct\b.*?}\s*\w+;", source, re.DOTALL))
        if index < 2:
            snippets.append(source[source.index("static "):source.index("static void GetViewDir")])
            functions = ("GetViewDir", "Act", "GetResources")
        else:
            functions = ("d11c_800C49A4", "ExtendVignette", "d11c_800C5094")
        snippets.extend(definition(source, name) for name in functions)
        snippets.append("#endif")
    args.output.write_text("\n\n".join(snippets) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
