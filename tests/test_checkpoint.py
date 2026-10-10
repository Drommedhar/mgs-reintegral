"""Run native checkpoint file checks without touching user saves."""

import subprocess
import sys
import tempfile
from pathlib import Path


def main():
    executable = Path(sys.argv[1]).resolve(strict=True)
    with tempfile.TemporaryDirectory(prefix="mgs-checkpoint-") as directory:
        subprocess.run([str(executable)], cwd=directory, check=True, timeout=15)


if __name__ == "__main__":
    main()
