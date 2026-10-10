"""Inventory recovered stage sources and native build/runtime evidence."""

import argparse
import json
from pathlib import Path

from stage_audit.inventory import inventory


def main() -> None:
    project = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=project)
    parser.add_argument("--source", type=Path, default=project / "vendor/mgs")
    parser.add_argument(
        "--output", type=Path, default=project / "docs/data/stage_inventory.json"
    )
    parser.add_argument("--compile-commands", type=Path, action="append", default=[])
    parser.add_argument("--runtime-log", type=Path, action="append", default=[])
    args = parser.parse_args()
    result = inventory(args)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result["summary"]))


if __name__ == "__main__":
    main()
