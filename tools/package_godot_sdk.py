"""Stage a relocatable game or SDK release from explicit code and tool inputs."""

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import zipfile
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
GODOT = Path("renderers/godot/project")
CODE = {".gd", ".uid", ".tscn", ".tres", ".gdshader", ".gdshaderinc"}
SCRIPTS = (
    "sdk.ps1",
    "sdk-paths.ps1",
    "prepare-python.ps1",
    "sdk-bootstrap.ps1",
    "download-tool.ps1",
    "run.ps1",
    "run-godot.ps1",
    "run-godot-editor.ps1",
    "prepare-godot.ps1",
    "prepare-godot-content.ps1",
    "input-session.ps1",
    "resume-input.ps1",
    "prepare-input-resume.py",
    "import_content.py",
    "prepare_godot_assets.py",
    "prepare_loading_animation.py",
    "list_assets.py",
    "language_script.py",
    "import_godot_mod.py",
    "validate_godot_mod.py",
    "fork_godot_mod.py",
)


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


class Package:
    def __init__(self, output):
        self.root = output
        self.files = {}
        output.mkdir(parents=True, exist_ok=False)

    def copy(self, source, relative):
        relative = Path(relative)
        if relative.is_absolute() or ".." in relative.parts or source.is_symlink():
            raise ValueError(f"Unsafe package input: {source} -> {relative}")
        destination = self.root / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)
        self.files[relative.as_posix()] = digest(destination)

    def tree(self, source, destination, suffixes=None):
        if not source.is_dir():
            raise FileNotFoundError(source)
        for path in sorted(source.rglob("*")):
            relative = path.relative_to(source)
            if any(
                part.startswith(".") or part == "__pycache__" for part in relative.parts
            ):
                continue
            if path.is_file() and (suffixes is None or path.suffix in suffixes):
                self.copy(path, Path(destination) / relative)

    def write(self, relative, text):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8", newline="\n")
        self.files[Path(relative).as_posix()] = digest(path)

    def json(self, relative, value):
        self.write(relative, json.dumps(value, indent=2) + "\n")


def copy_project(package, kind="sdk"):
    for path in sorted((PROJECT / GODOT).iterdir()):
        source = path.with_suffix("") if path.suffix == ".uid" else path
        if path.is_file() and source.suffix in {".gd", ".gdshader", ".gdshaderinc"}:
            package.copy(path, GODOT / path.name)
    package.copy(PROJECT / GODOT / "main.tscn", GODOT / "main.tscn")
    package.copy(
        PROJECT / GODOT / "map_environment.tres", GODOT / "map_environment.tres"
    )
    config = (PROJECT / GODOT / "project.godot").read_text(encoding="utf-8")
    if kind == "game":
        config = config.replace(
            'enabled=PackedStringArray("res://addons/mgs_editor/plugin.cfg")',
            "enabled=PackedStringArray()",
        )
    package.write(GODOT / "project.godot", config)
    package.copy(
        PROJECT / GODOT / "re-integral-logo.png", GODOT / "re-integral-logo.png"
    )
    for name in (
        "loading-snake.png",
        "interface-font.png",
        "interface-font.json",
        "texgyreheros-regular.otf",
    ):
        package.copy(PROJECT / GODOT / name, GODOT / name)
    if kind == "sdk":
        copy_authoring(package)
    package.tree(PROJECT / GODOT / "addons/mgs_water", GODOT / "addons/mgs_water", CODE)
    package.tree(PROJECT / GODOT / "addons/mgs_snow", GODOT / "addons/mgs_snow", CODE)
    for shader in (
        "psx.vert.glsl",
        "psx.frag.glsl",
        "legacy-debug-font.bin",
        "SDL_render_debug_font.h",
    ):
        relative = GODOT / ".generated" / shader
        package.copy(PROJECT / relative, relative)
    for script in SCRIPTS:
        package.copy(PROJECT / "tools" / script, Path("tools") / script)
    package.tree(PROJECT / "tools/godot_assets", "tools/godot_assets", {".py"})
    package.copy(PROJECT / "config/stages.json", "config/stages.json")
    package.copy(PROJECT / "sources.lock.json", "sources.lock.json")


def copy_authoring(package):
    package.tree(
        PROJECT / GODOT / "addons/mgs_editor",
        GODOT / "addons/mgs_editor",
        CODE | {".cfg", ".json"},
    )
    for example in (
        "lighting",
        "native_elevator",
        "presentation_camera",
        "named_resources",
        "layered_maps",
        "water_frost",
        "snow",
    ):
        package.tree(
            PROJECT / GODOT / "examples" / example,
            GODOT / "examples" / example,
            CODE | {".json", ".md"},
        )
    package.copy(
        PROJECT / GODOT / "examples/make_map_demo.gd",
        GODOT / "examples/make_map_demo.gd",
    )
    package.tree(
        PROJECT / "renderers/godot/sdk",
        "renderers/godot/sdk",
        {".cpp", ".h", ".json", ".txt", ".tscn", ".gdextension"},
    )


def copy_runtime(package, build, legacy):
    manifest = json.loads((build / "renderer.json").read_text())
    if manifest.get("backend") != "godot":
        raise ValueError("SDK requires the Godot native host build")
    for name in ("mgs-integral-native.exe", "settings-host.exe"):
        package.copy(build / name, Path("build/windows-x86-godot") / name)
    package.copy(build / "RE-INTEGRAL.exe", "RE-INTEGRAL.exe")
    package.tree(build / "language-importer", "language-importer")
    manifest.update(
        executable="build/windows-x86-godot/mgs-integral-native.exe",
        godotExecutable=".tools/godot-4.8-dev7/Godot_v4.8-dev7_win64_console.exe",
        godotProject=GODOT.as_posix(),
        godotAssets=".local/godot-content",
    )
    package.json("renderer.json", manifest)
    baseline = json.loads((PROJECT / "docs/data/godot_sdk_baseline.json").read_text())
    expected = baseline["legacy_archive_members"][
        "reintegral-0.2.0-alpha.1-windows-x86/mgs-integral-native.exe"
    ]
    if digest(legacy / "mgs-integral-native.exe") != expected:
        raise ValueError("Legacy executable differs from preserved 0.2 baseline")
    package.copy(
        legacy / "mgs-integral-native.exe", "renderers/legacy/mgs-integral-native.exe"
    )
    package.json(
        "renderers/legacy/renderer.json",
        {
            "schema": 1,
            "launchApi": 1,
            "id": "legacy",
            "name": "Legacy 0.2",
            "version": "0.2.0-alpha.1",
            "backend": "native",
            "nativeArchitecture": "x86",
            "rendererArchitecture": "x86",
            "executable": "mgs-integral-native.exe",
            "nativeGraphicsOptions": False,
        },
    )


def copy_tools(package, options):
    package.tree(options.godot_notices, "licenses/godot")
    actions = (
        ("Editor", "Prepare", "Play") if options.kind == "sdk" else ("Prepare", "Play")
    )
    for action in actions:
        package.write(
            f"{action}.cmd",
            '@echo off\nsetlocal\n"%SystemRoot%\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\\sdk-bootstrap.ps1" -Action '
            + action.lower()
            + ' %*\nset "result=%errorlevel%"\nif not "%result%"=="0" pause\nexit /b %result%\n',
        )


def copy_notices(package, legacy, legacy_source):
    package.copy(PROJECT / "LICENSE", "LICENSE")
    package.tree(PROJECT / "licenses/fonts", "licenses/fonts")
    package.tree(PROJECT / "licenses/loading-animation", "licenses/loading-animation")
    package.copy(
        PROJECT / "assets/fonts/mgs1-codec-gleeson.ttf",
        "assets/fonts/mgs1-codec-gleeson.ttf",
    )
    package.copy(
        PROJECT / "tools/build_interface_font.py", "tools/build_interface_font.py"
    )
    package.copy(PROJECT / "requirements-fonts.txt", "requirements-fonts.txt")
    package.tree(legacy / "licenses", "licenses/native")
    package.copy(
        legacy_source,
        "source/legacy-0.2-mpl-source.zip",
    )
    for name in (
        "THIRD_PARTY.md",
        "PLAYER_GUIDE.md",
        "MOD_CREATOR_GUIDE.md",
        "ALPHA.md",
        "LANGUAGES.md",
        "REGIONAL_LANGUAGE_RESOURCES.md",
        "GODOT_MODDING.md",
        "GODOT_SDK_MASTER_PLAN.html",
        "RENDERER_PACKAGES.md",
        "GODOT_PROTOCOL.md",
        "LEGACY_GODOT_PARITY.md",
        "PRESENTATION_CONTRACT.md",
        "PRESENTATION_HOST.md",
        "SETTINGS_CONTRACT.md",
        "GODOT_CINEMATIC_AUTHORING.md",
        "GODOT_WATER_FROST.md",
        "GODOT_SNOW.md",
        "SDK_QUICKSTART.md",
        "RELEASE_0.3.md",
        "GODOT_NATIVE_BINDING_NOTES.md",
        "GODOT_PRESENTATION_COVERAGE.md",
        "MOVIE_VALIDATION.md",
    ):
        package.copy(PROJECT / "docs" / name, Path("docs") / name)
    package.write(
        "START-HERE.md",
        (PROJECT / "docs/SDK_QUICKSTART.md")
        .read_text(encoding="utf-8")
        .replace("](PLAYER_GUIDE.md)", "](docs/PLAYER_GUIDE.md)")
        .replace("](MOD_CREATOR_GUIDE.md)", "](docs/MOD_CREATOR_GUIDE.md)")
        .replace("](GODOT_MODDING.md)", "](docs/GODOT_MODDING.md)")
        .replace("](GODOT_WATER_FROST.md)", "](docs/GODOT_WATER_FROST.md)")
        .replace("](GODOT_SNOW.md)", "](docs/GODOT_SNOW.md)")
        .replace("](GODOT_SDK_MASTER_PLAN.html)", "](docs/GODOT_SDK_MASTER_PLAN.html)")
        .replace("](RELEASE_0.3.md)", "](docs/RELEASE_0.3.md)"),
    )
    for part in ("platform", "psyz"):
        package.tree(
            PROJECT / "vendor/psyz/psyz/src" / part, Path("source/psyz") / part
        )
    package.tree(
        PROJECT / "renderers/godot/native", "source/godot-native", {".c", ".h", ".txt"}
    )
    package.write(
        "SOURCE-AND-NOTICES.txt",
        "See docs/THIRD_PARTY.md for license scopes and docs/RELEASE_0.3.md for release scope.\nModified MPL source for the current host is in source/psyz under MPL 2.0; see licenses/native/MPL-2.0.txt.\nThe preserved Legacy 0.2 MPL source is in source/legacy-0.2-mpl-source.zip.\nDownloaded tools retain their own notices; Godot notices are in licenses/godot.\n",
    )
    package.copy(PROJECT / "patches/psyz-movies.patch", "patches/psyz-movies.patch")
    for relative in (
        "patches/mgs-movies.patch",
        "tests/test_vlc.c",
        "tests/test_mdec_decode.c",
        "tests/test_cd.c",
        "docs/data/godot_presentation_coverage.json",
    ):
        package.copy(PROJECT / relative, relative)
    package.copy(PROJECT / "renderers/modern/README.md", "renderers/modern/README.md")


def finish(package, build, version, kind, local):
    from sdk_package_audit import audit

    configuration = next(
        line.split("=", 1)[1]
        for line in (build / "CMakeCache.txt").read_text().splitlines()
        if line.startswith("CMAKE_BUILD_TYPE:STRING=")
    )
    commit = subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=PROJECT, text=True
    ).strip()
    engine = subprocess.check_output(
        [str(build / "mgs-integral-native.exe"), "--version"], text=True
    ).strip()
    if not engine.startswith(f"RE:INTEGRAL {version} ("):
        raise ValueError(f"Native build version does not match {version}: {engine}")
    if engine != f"RE:INTEGRAL {version} ({commit[:12]})":
        raise ValueError(f"Native build commit does not match {commit}: {engine}")
    package.json(
        "sdk.json",
        {
            "schema": 1,
            "packageId": package.root.name,
            "channel": "stable",
            "version": version,
            "kind": kind,
            "nativeBuild": engine,
            "sourceCommit": commit,
            "sourceWorktreeDirty": bool(
                subprocess.check_output(
                    ["git", "status", "--porcelain", "--untracked-files=normal"],
                    cwd=PROJECT,
                    text=True,
                ).strip()
            ),
            "nativeConfiguration": configuration,
            "godot": "4.8.dev7.official.c971f93e7",
            "presentationProtocol": "15.35",
            "visualApi": 1,
            "tools": json.loads((PROJECT / "sources.lock.json").read_text())[
                "sdkTools"
            ],
        },
    )
    package.json(
        "package-files.json",
        {"schema": 1, "sha256": dict(sorted(package.files.items()))},
    )
    audit(package.root, package.files, local)
    archive = package.root.with_name(package.root.name + ".zip")
    if archive.exists():
        raise FileExistsError(archive)
    with zipfile.ZipFile(archive, "x", zipfile.ZIP_DEFLATED, compresslevel=6) as output:
        for path in sorted(package.root.rglob("*")):
            if path.is_file():
                output.write(
                    path,
                    (
                        Path(package.root.name) / path.relative_to(package.root)
                    ).as_posix(),
                )
    archive.with_suffix(".zip.sha256").write_text(
        digest(archive) + "  " + archive.name + "\n", encoding="ascii"
    )
    print(
        json.dumps(
            {
                "directory": str(package.root),
                "archive": str(archive),
                "files": len(package.files),
            }
        )
    )


def stable_version(value):
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", value):
        raise argparse.ArgumentTypeError("Use a stable version such as 0.3.0")
    return value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("output", "build", "legacy", "legacy-source", "godot-notices"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--version", type=stable_version, required=True)
    parser.add_argument("--kind", choices=("sdk", "game"), default="sdk")
    parser.add_argument("--local-content", type=Path)
    options = parser.parse_args()
    package = Package(options.output.resolve())
    copy_project(package, options.kind)
    copy_runtime(package, options.build, options.legacy)
    copy_tools(package, options)
    copy_notices(package, options.legacy, options.legacy_source)
    if options.kind == "game":
        package.write(
            "START-HERE.md",
            "# RE:INTEGRAL\n\nStart with [the player guide](docs/PLAYER_GUIDE.md).\n"
            f"Release notes: [{options.version}](docs/RELEASE_0.3.md).\n",
        )
    finish(package, options.build, options.version, options.kind, options.local_content)


if __name__ == "__main__":
    main()
