"""Run card regressions in private directories, including process restart."""

import argparse
import subprocess
import tempfile
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("probe", type=Path)
    arguments = parser.parse_args()
    executable = arguments.probe.resolve(strict=True)
    for cases in (
        ("write", "verify"),
        ("events",),
        ("capacity",),
        ("game-write", "game-verify"),
    ):
        with tempfile.TemporaryDirectory(prefix="mgs-save-test-") as directory:
            for case in cases:
                subprocess.run(
                    [str(executable), case], cwd=directory, check=True, timeout=20
                )


if __name__ == "__main__":
    main()
