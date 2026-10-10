"""Select recovered Liquid state routines for original-instruction comparisons."""

import argparse
from pathlib import Path

from prepare_mantis_test import definition

ADDRESSES = [
    "CD4AC",
    "CD504",
    "CD544",
    "CDC40",
    "CDCD4",
    "CDD28",
    "CDD68",
    "CE0F8",
    "CE170",
    "CE314",
    "CE3F8",
    "CE4CC",
    "CE530",
    "CE584",
    "CE634",
    "CE674",
    "CE93C",
    "CE97C",
    "CEB78",
    "CEBC4",
    "CED40",
    "CED80",
    "CEDCC",
    "CEE0C",
    "CEE58",
    "CEF30",
    "CEF70",
    "CEFE4",
    "CF090",
    "CF0EC",
    "CF138",
    "CF184",
    "CF1CC",
    "CF338",
    "CF470",
    "CF4BC",
    "CF508",
    "CF554",
    "CF5DC",
    "CF628",
    "CF684",
    "CF6E0",
    "CF72C",
    "CF778",
    "CF7E4",
    "CF838",
    "CF884",
    "CF8F0",
    "CF94C",
    "CF998",
    "CF9E4",
    "CFA50",
    "CFA90",
    "CFAEC",
    "CFB48",
    "CFB94",
    "CFBE0",
    "CFC24",
    "CFC70",
    "CFCB4",
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    directory = root / "vendor/mgs/source/animal/liquid"
    source = "\n".join(
        (directory / f"liquid_{part}.c").read_text(encoding="utf-8")
        for part in ("think", "tactics", "sequence")
    )
    names = ["liquid_800" + address for address in ADDRESSES]
    snippets = [definition(source, name) for name in names]
    snippets.append(
        "static const struct LiquidTestRoutine {\n"
        "    LiquidUpdate update;\n"
        "    int (*query)(LiquidWork *);\n"
        "} liquid_test_routines[] = {"
    )
    snippets.extend(
        f"    {{NULL, {name}}}," if index < 3 else f"    {{{name}, NULL}},"
        for index, name in enumerate(names)
    )
    snippets.append("};")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n\n".join(snippets) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
