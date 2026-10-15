"""Exercise extracted release tools and editor operations without discs or a GPU."""

import argparse
import json
import os
import shutil
import subprocess
import zipfile
from pathlib import Path

from verify_godot_package import verify

ROOT = Path(__file__).resolve().parents[1]


def run(arguments, log, marker=None, headless_thumbnail=False):
    with log.open("w", encoding="utf-8") as output:
        subprocess.run(
            arguments, stdout=output, stderr=subprocess.STDOUT, check=True, timeout=300
        )
    text = log.read_text(encoding="utf-8", errors="replace")
    if headless_thumbnail:
        text = text.replace(
            'ERROR: Parameter "t" is null.\n   at: texture_2d_get (./servers/rendering/dummy/storage/texture_storage.h:110)',
            "Headless renderer cannot create an editor thumbnail.",
        )
    if "ERROR:" in text or (marker and marker not in text):
        raise ValueError(f"Release smoke check failed: {log}")


def extract(archive, destination):
    verify(archive)
    with zipfile.ZipFile(archive) as source:
        source.extractall(destination)
    return destination / archive.stem


def check_release(sdk_archive, game_archive, output, downloads):
    output.mkdir(parents=True, exist_ok=False)
    sdk = extract(sdk_archive, output / "relocated SDK ü")
    if downloads:
        shutil.copytree(downloads, sdk / ".tools/downloads")
    cmd = f'"{os.environ["COMSPEC"]}" /d /s /c ""{sdk / "Editor.cmd"}" -ToolsOnly"'
    run(cmd, output / "bootstrap.log")
    if (sdk / ".tools/python").exists():
        raise ValueError("Editor installed Python before a Python operation")
    godot = sdk / ".tools/godot-4.8-dev7/Godot_v4.8-dev7_win64_console.exe"
    project = sdk / "renderers/godot/project"
    run(
        [str(godot), "--headless", "--editor", "--path", str(project), "--import"],
        output / "sdk-import.log",
    )
    fixture = project / "addons/release_test"
    fixture.mkdir()
    shutil.copyfile(
        ROOT / "renderers/godot/project/tests/sdk_download_editor_test.gd",
        fixture / "test.gd",
    )
    (fixture / "plugin.cfg").write_text(
        '[plugin]\nname="Release test"\nauthor="RE:INTEGRAL"\nversion="1"\nscript="test.gd"\n'
    )
    config = project / "project.godot"
    config.write_text(
        config.read_text().replace(
            '"res://addons/mgs_editor/plugin.cfg"',
            '"res://addons/mgs_editor/plugin.cfg", "res://addons/release_test/plugin.cfg"',
        )
    )
    with zipfile.ZipFile(sdk / "fixture.zip", "w") as archive:
        archive.writestr(
            "mod.json",
            json.dumps(
                {
                    "schema": 1,
                    "id": "test.release",
                    "stages": {"s00a": {"scene": "scene.tscn"}},
                }
            ),
        )
        archive.writestr(
            "scene.tscn",
            '[gd_scene format=3]\n[node name="CustomScene" type="Node3D"]\n',
        )
    run(
        [str(godot), "--headless", "--editor", "--path", str(project)],
        output / "editor.log",
        "MGS_SDK_DOWNLOAD_EDITOR_TEST failures=0",
        headless_thumbnail=True,
    )
    game = extract(game_archive, output / "relocated game ü")
    run(
        [
            str(godot),
            "--headless",
            "--editor",
            "--path",
            str(game / "renderers/godot/project"),
            "--import",
        ],
        output / "game-import.log",
    )
    (output / "verified.json").write_text(
        json.dumps(
            {
                "sdk": sdk_archive.name,
                "game": game_archive.name,
                "editor": "Open ZIP, lazy Python, Save As and damaged Python repair passed",
                "headlessImports": 2,
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sdk", type=Path, required=True)
    parser.add_argument("--game", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--downloads", type=Path)
    args = parser.parse_args()
    check_release(
        args.sdk.resolve(), args.game.resolve(), args.output.resolve(), args.downloads
    )
