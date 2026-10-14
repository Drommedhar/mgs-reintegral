"""Build the independent presentation sample and audit its relocatable package."""

import argparse
import json
import os
import subprocess
import tempfile
import zipfile
from pathlib import Path

from package_godot_sdk import PROJECT, Package, digest
from sdk_package_audit import audit


def compile_sample(package):
    compiler = Path(os.environ["WINDIR"]) / "Microsoft.NET/Framework/v4.0.30319/csc.exe"
    sources = PROJECT / "renderers/community-wireframe"
    with tempfile.TemporaryDirectory(prefix="reintegral-wireframe-") as temporary:
        executable = Path(temporary) / "wireframe.exe"
        subprocess.run(
            [
                str(compiler),
                "/nologo",
                "/target:exe",
                "/platform:x86",
                "/optimize+",
                "/reference:System.Windows.Forms.dll",
                "/reference:System.Drawing.dll",
                "/reference:System.Web.Extensions.dll",
                f"/out:{executable}",
                *(
                    str(sources / name)
                    for name in ("Program.cs", "Surface.cs", "Wire.cs")
                ),
            ],
            check=True,
        )
        package.copy(executable, "wireframe.exe")
    package.tree(sources, "source/community-wireframe", {".cs", ".ps1"})


def copy_notices_and_source(package):
    notices = {
        "psyz-scopes.txt": "vendor/psyz/LICENSE",
        "psyz-decomp-MIT.txt": "vendor/psyz/decomp/LICENSE",
        "MPL-2.0.txt": "vendor/psyz/psyz/src/psyz/LICENSE",
        "psxe-MIT.txt": "vendor/psyz/psyz/LICENSE-psxe.txt",
        "SDL-zlib.txt": "vendor/psyz/external/SDL/LICENSE.txt",
        "HIDAPI-BSD.txt": "vendor/psyz/external/SDL/src/hidapi/LICENSE-bsd.txt",
        "yuv2rgb-BSD.txt": "vendor/psyz/external/SDL/src/video/yuv2rgb/LICENSE",
        "Apache-2.0.txt": "licenses/Apache-2.0.txt",
    }
    for name, source in notices.items():
        package.copy(PROJECT / source, Path("licenses") / name)
    stb = (PROJECT / "vendor/psyz/psyz/src/dbgserver/stb_image_write.h").read_text()
    notice_start = stb.index("This software is available under 2 licenses")
    package.write("licenses/stb_image_write.txt", stb[notice_start:])
    package.copy(PROJECT / "LICENSE", "LICENSE")
    package.copy(PROJECT / "sources.lock.json", "sources.lock.json")
    for part in ("platform", "psyz"):
        package.tree(
            PROJECT / "vendor/psyz/psyz/src" / part, Path("source/psyz") / part
        )
    package.tree(
        PROJECT / "renderers/godot/native", "source/godot-native", {".c", ".h", ".txt"}
    )
    package.tree(PROJECT / "patches", "source/patches", {".patch"})
    for name in (
        "THIRD_PARTY.md",
        "RENDERER_PACKAGES.md",
        "PRESENTATION_HOST.md",
        "PRESENTATION_CONTRACT.md",
        "GODOT_PROTOCOL.md",
        "SETTINGS_CONTRACT.md",
    ):
        package.copy(PROJECT / "docs" / name, Path("docs") / name)
    package.copy(PROJECT / "renderers/community-wireframe/README.md", "START-HERE.md")
    package.write(
        "SOURCE-AND-NOTICES.txt",
        "Development presentation-host package. License scopes and unresolved upstream terms are documented in docs/THIRD_PARTY.md.\n"
        "Modified MPL source is included in source/psyz and source/godot-native under MPL 2.0; see licenses/MPL-2.0.txt.\n"
        "The independent sample and its build script are in source/community-wireframe, under the project LICENSE.\n"
        "Pinned revisions and modifications are recorded in sources.lock.json and source/patches. No original disc assets are included.\n",
    )


def finish(package, build):
    configuration = next(
        line.split("=", 1)[1]
        for line in (build / "CMakeCache.txt").read_text().splitlines()
        if line.startswith("CMAKE_BUILD_TYPE:STRING=")
    )
    package.json(
        "build-info.json",
        {
            "channel": "development",
            "nativeConfiguration": configuration,
            "presentationProtocol": "15.30",
            "sourceCommit": subprocess.check_output(
                ["git", "rev-parse", "HEAD"], cwd=PROJECT, text=True
            ).strip(),
        },
    )
    package.json(
        "package-files.json",
        {"schema": 1, "sha256": dict(sorted(package.files.items()))},
    )
    audit(package.root, package.files, PROJECT / ".local")
    archive = package.root.with_suffix(".zip")
    with zipfile.ZipFile(archive, "x", zipfile.ZIP_DEFLATED, compresslevel=6) as output:
        for relative in sorted(package.files):
            output.write(
                package.root / relative, (Path(package.root.name) / relative).as_posix()
            )
    with zipfile.ZipFile(archive) as output:
        if output.testzip() is not None:
            raise ValueError("Community renderer archive failed its CRC check")
    archive.with_suffix(".zip.sha256").write_text(
        digest(archive) + "  " + archive.name + "\n", encoding="ascii"
    )
    print(
        json.dumps(
            {
                "archive": str(archive),
                "files": len(package.files),
                "sha256": digest(archive),
            }
        )
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--build", required=True, type=Path)
    options = parser.parse_args()
    descriptor = json.loads(
        (options.build / "renderer.json").read_text(encoding="utf-8-sig")
    )
    if descriptor["backend"] != "godot":
        raise ValueError("Use the current presentation host build")
    if options.output.with_suffix(".zip").exists():
        raise FileExistsError(options.output.with_suffix(".zip"))
    package = Package(options.output.resolve())
    compile_sample(package)
    package.copy(options.build / "mgs-integral-native.exe", "presentation-host.exe")
    copy_notices_and_source(package)
    package.json(
        "renderer.json",
        {
            "schema": 1,
            "launchApi": 2,
            "id": "example.wireframe",
            "name": "Community wireframe sample",
            "version": "0.1.0",
            "backend": "companion",
            "nativeArchitecture": "x86",
            "rendererArchitecture": "x86",
            "executable": "presentation-host.exe",
            "companionExecutable": "wireframe.exe",
            "companionArguments": [],
            "protocol": {
                "major": 15,
                "minor": 30,
                "capabilities": 29,
                "mode": "commands",
            },
        },
    )
    finish(package, options.build)


if __name__ == "__main__":
    main()
