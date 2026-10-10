"""Exercise the native disc-change boundary with two complete synthetic images."""

import argparse
import subprocess
import tempfile
from pathlib import Path

from tests.test_safety import CUE, sector_fixture


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("probe", type=Path)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="mgs-disc-change-") as temporary:
        paths = []
        for number in (1, 2):
            directory = Path(temporary) / f"disc{number}"
            directory.mkdir()
            content = b"".join(sector_fixture())
            if number == 2:
                content = content.replace(b"SLPM_862.47", b"SLPM_862.48")
            (directory / "disc.bin").write_bytes(content)
            cue = directory / "disc.cue"
            cue.write_text(CUE, encoding="ascii")
            paths.append(str(cue))
        subprocess.run([str(args.probe.resolve()), *paths], check=True, timeout=10)


if __name__ == "__main__":
    main()
