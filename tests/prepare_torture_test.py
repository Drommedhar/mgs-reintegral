"""Extract the production torture round, recovery, and surrender routines."""

import argparse
from pathlib import Path

from prepare_mantis_test import definition


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    output = parser.parse_args().output
    source = (
        Path(__file__).resolve().parent.parent
        / "vendor/mgs/source/chara/torture/torture.c"
    ).read_text(encoding="utf-8")
    start = source.index("struct _Work;")
    end = source.index("} Work;", start) + len("} Work;")
    snippets = [
        source[start:end],
        "void s03b_torture_800C447C(Work *, int, int);",
        "void s03b_torture_800C5420(Work *, int);",
    ]
    names = (
        "s03b_torture_800C4654",
        "s03b_torture_800C5E48",
        "s03b_torture_800C3EB8",
        "s03b_torture_800C4314",
        "s03b_torture_800C5AF8",
    )
    snippets.extend(definition(source, name) for name in names)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n\n".join(snippets) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
