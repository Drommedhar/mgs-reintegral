"""Check the unpacked player package using synthetic discs, without retail data."""

import argparse
import hashlib
import json
import os
import subprocess
import tempfile
import zipfile
from pathlib import Path

from tests.test_safety import CUE, sector_fixture


def run_engine(executable: Path, arguments: list[str], directory: Path, expected=0):
    result = subprocess.run(
        [str(executable), *arguments],
        cwd=directory,
        capture_output=True,
        encoding="utf-8",
        timeout=20,
    )
    if result.returncode != expected:
        raise AssertionError(
            f"{arguments}: exit {result.returncode}\n{result.stdout}\n{result.stderr}"
        )
    return result.stdout


def check_discs(executable: Path, directory: Path):
    paths = []
    for number in (1, 2):
        disc = directory / f"disc {number} ü 日本語"
        disc.mkdir()
        image = b"".join(sector_fixture())
        if number == 2:
            image = image.replace(b"SLPM_862.47", b"SLPM_862.48")
        (disc / "disc.bin").write_bytes(image)
        cue = disc / "disc.cue"
        cue.write_text(CUE, encoding="utf-8")
        paths.append(cue)
        run_engine(executable, ["--check-disc", str(number), str(cue)], directory)
        run_engine(
            executable, ["--check-disc", str(3 - number), str(cue)], directory, 2
        )
        if (
            hashlib.sha256((disc / "disc.bin").read_bytes()).digest()
            != hashlib.sha256(image).digest()
        ):
            raise AssertionError("Disc validation modified the image")
    paths[0].write_text(CUE.replace("disc.bin", "missing.bin"), encoding="utf-8")
    run_engine(executable, ["--check-disc", "1", str(paths[0])], directory, 2)


def check_package(package: Path, ui: bool):
    with tempfile.TemporaryDirectory(prefix="reintegral package ü ") as temporary:
        directory = Path(temporary)
        with zipfile.ZipFile(package) as archive:
            for entry in archive.namelist():
                if Path(entry).suffix.lower() in {
                    ".bin",
                    ".cue",
                    ".iso",
                    ".pdb",
                    ".mgslang",
                    ".dat",
                    ".dir",
                }:
                    raise AssertionError(f"Unexpected player-package file: {entry}")
            archive.extractall(directory)
        (executable,) = directory.glob("*/mgs-integral-native.exe")
        info = json.loads(
            (executable.parent / "build-info.json").read_text(encoding="utf-8-sig")
        )
        version = run_engine(executable, ["--version"], directory)
        if info["version"] not in version or info["commit"][:12] not in version:
            raise AssertionError("Package and executable source identities differ")
        run_engine(executable, ["--help"], directory)
        check_discs(executable, directory)
        check_importer(executable.parent, directory)
        if ui:
            subprocess.run(
                [
                    str(executable.with_name("RE-INTEGRAL.exe")),
                    "--smoke-ui",
                    "--data-dir",
                    str(directory / "profile ü 日本語"),
                ],
                check=True,
                timeout=20,
            )
    print(
        "Player package: version, Unicode paths, both discs, wrong discs, missing image, and read-only checks passed."
    )


def check_importer(application: Path, directory: Path):
    importer = application / "language-importer" / "language-importer.exe"
    environment = {
        **os.environ,
        "PATH": str(Path(os.environ["SystemRoot"]) / "System32"),
    }
    environment.pop("PYTHONHOME", None)
    environment.pop("PYTHONPATH", None)
    result = subprocess.run(
        [str(importer), "--help"],
        cwd=directory,
        env=environment,
        capture_output=True,
        encoding="utf-8",
        timeout=20,
        check=True,
    )
    if "--base-two" not in result.stdout:
        raise AssertionError("Bundled importer has no disc-pair workflow")
    invalid = directory / "invalid regional disc ü.bin"
    invalid.write_bytes(bytes(2352))
    arguments = [
        str(importer),
        "--language",
        "de",
        "--output",
        str(directory / "output.mgslang"),
    ]
    for option in ("--disc-one", "--disc-two", "--base-one", "--base-two"):
        arguments.extend((option, str(invalid)))
    result = subprocess.run(
        arguments,
        cwd=directory,
        env=environment,
        capture_output=True,
        encoding="utf-8",
        timeout=20,
    )
    if result.returncode != 2 or "Language import failed" not in result.stderr:
        raise AssertionError(
            f"Bundled importer failed its invalid-disc check: {result.stderr}"
        )
    if invalid.read_bytes() != bytes(2352) or (directory / "output.mgslang").exists():
        raise AssertionError("Failed import changed source data or installed a pack")
    for name in (
        "Python.txt",
        "PyInstaller.txt",
        "Apache-2.0.txt",
        "zlib.txt",
        "importer-runtime.txt",
    ):
        if not (importer.parent / "licenses" / name).is_file():
            raise AssertionError(f"Missing importer notice: {name}")
    print(
        "Bundled importer: help and invalid-disc rejection work without Python on PATH."
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", type=Path)
    parser.add_argument("--ui", action="store_true")
    options = parser.parse_args()
    check_package(options.package.resolve(), options.ui)
