"""Check resident resource transitions and strict unknown-stage rejection."""

import argparse
import subprocess
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("probe", type=Path)
    args = parser.parse_args()
    executable = str(args.probe.resolve())
    subprocess.run([executable], check=True, timeout=10)
    cases = (
        ("initial", "Stage 'initial' has not been linked"),
        ("init_veryeasy", "Resource stage name exceeds its disc directory field."),
        ("s99z", "Stage 's99z' has not been linked"),
    )
    for name, diagnostic in cases:
        result = subprocess.run(
            [executable, name], capture_output=True, text=True, timeout=10, check=False
        )
        assert result.returncode != 0, name
        assert diagnostic in result.stderr, result.stderr


if __name__ == "__main__":
    main()
