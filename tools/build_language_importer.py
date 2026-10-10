"""Bundle the local importer and its interpreter; never collect retail assets."""

import argparse
import importlib.metadata
import json
import platform
import shutil
import ssl
import struct
import sys
import zlib
from pathlib import Path

import PyInstaller.__main__


def build(directory: Path):
    if sys.platform != "win32" or struct.calcsize("P") != 8:
        raise RuntimeError("Build the language importer with 64-bit Windows Python.")
    if ssl.OPENSSL_VERSION_INFO[0] != 3:
        raise RuntimeError(
            "The importer runtime notices require a Python build using OpenSSL 3."
        )
    project = Path(__file__).resolve().parents[1]
    work = directory / "importer-build"
    work.mkdir(parents=True, exist_ok=True)
    PyInstaller.__main__.run(
        [
            "--noconfirm",
            "--onedir",
            "--console",
            "--noupx",
            "--name",
            "language-importer",
            "--distpath",
            str(directory),
            "--workpath",
            str(work / "work"),
            "--specpath",
            str(work),
            str(project / "tools" / "import_language.py"),
        ]
    )
    bundle = directory / "language-importer"
    notices = bundle / "licenses"
    notices.mkdir()
    shutil.copyfile(Path(sys.base_prefix) / "LICENSE.txt", notices / "Python.txt")
    installer = importlib.metadata.distribution("pyinstaller")
    (license_file,) = [f for f in installer.files if f.name == "COPYING.txt"]
    shutil.copyfile(installer.locate_file(license_file), notices / "PyInstaller.txt")
    for name in ("Apache-2.0.txt", "zlib.txt", "importer-runtime.txt"):
        shutil.copyfile(project / "licenses" / name, notices / name)
    (bundle / "build-info.json").write_text(
        json.dumps(
            {
                "python": platform.python_version(),
                "architecture": "x64",
                "pyinstaller": installer.version,
                "openssl": ssl.OPENSSL_VERSION,
                "zlib": zlib.ZLIB_RUNTIME_VERSION,
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-directory", type=Path, required=True)
    build(parser.parse_args().build_directory.resolve())
