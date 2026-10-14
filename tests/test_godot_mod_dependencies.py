"""Real Godot graph validation before an imported ZIP becomes editable."""

import base64
import json
import os
import subprocess
import sys
import tempfile
import unittest
import zipfile
from functools import partial
from pathlib import Path

from tools.import_godot_mod import open_mod
from tools.validate_godot_mod import validate_dependencies

REPOSITORY = Path(__file__).resolve().parents[1]
PROJECT = REPOSITORY / "renderers/godot/project"
GODOT = Path(
    os.environ.get(
        "MGS_GODOT_EXECUTABLE",
        REPOSITORY / ".tools/godot-4.8-dev7/Godot_v4.8-dev7_win64_console.exe",
    )
)


class ModDependencyImport(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.archive = self.root / "nested.zip"
        self.mods = self.root / "mods"
        self.validate = partial(validate_dependencies, godot=GODOT, project=PROJECT)
        self.files = {
            "mod.json": json.dumps(
                {
                    "schema": 1,
                    "id": "test.nested",
                    "stages": {"s00a": {"scene": "map.tscn"}},
                }
            ),
            "map.tscn": '[gd_scene format=3]\n[ext_resource type="Script" path="scripts/main.gd" id="1"]\n[node name="Map" type="Node3D"]\nscript = ExtResource("1")\n',
            "scripts/main.gd": 'extends "base.gd"\nconst PAINT = preload("../materials/paint.tres")\n# load("unused.tres")\nconst EXAMPLE = "preload(\'unused.tres\')"\n',
            "scripts/base.gd": "extends Node3D\n",
            "materials/paint.tres": '[gd_resource type="ShaderMaterial" format=3]\n[ext_resource type="Shader" path="surface.gdshader" id="1"]\n[ext_resource type="Texture2D" path="paint.png" id="2"]\n[resource]\nshader = ExtResource("1")\nshader_parameter/paint = ExtResource("2")\n',
            "materials/surface.gdshader": 'shader_type spatial;\n/* #include "unused.gdshaderinc" */\n#include "lib/tint.gdshaderinc"\nvoid fragment() { ALBEDO = tint(); }\n',
            "materials/lib/tint.gdshaderinc": "vec3 tint() { return vec3(0.2, 0.3, 0.4); }\n",
            "materials/paint.png": base64.b64decode(
                "iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAYAAAD0In+KAAAAEUlEQVR4nGMQ1wz/X30v/T8ADzgEVh3kdBgAAAAASUVORK5CYII="
            ),
        }

    def write_zip(self):
        with zipfile.ZipFile(self.archive, "w") as archive:
            for name, content in self.files.items():
                archive.writestr(name, content)

    def test_nested_graph_opens_without_import_cache_and_preserves_source(self):
        self.write_zip()
        original = self.archive.read_bytes()
        workspace = open_mod(self.archive, self.mods, self.validate)
        for name, content in self.files.items():
            expected = content.encode("utf-8") if isinstance(content, str) else content
            self.assertEqual((workspace / name).read_bytes(), expected)
        self.assertEqual(list(workspace.rglob("*.import")), [])
        scene = workspace / "map.tscn"
        scene.write_text("later local edit", encoding="utf-8")
        self.assertEqual(open_mod(self.archive, self.mods, self.validate), workspace)
        self.assertEqual(scene.read_text(), "later local edit")
        self.assertEqual(self.archive.read_bytes(), original)

    def test_each_missing_nested_resource_is_rejected_atomically(self):
        dependencies = list(self.files)[2:]
        for name in dependencies:
            with self.subTest(name=name):
                content = self.files.pop(name)
                self.write_zip()
                original = self.archive.read_bytes()
                with self.assertRaisesRegex(
                    ValueError, "dependency is missing"
                ) as error:
                    open_mod(self.archive, self.mods, self.validate)
                self.assertIn(name, str(error.exception))
                self.assertEqual(list(self.mods.iterdir()), [])
                self.assertEqual(self.archive.read_bytes(), original)
                self.files[name] = content

    def test_reference_outside_package_is_rejected(self):
        self.files["scripts/base.gd"] = 'extends "res://native_actor_binding.gd"\n'
        self.write_zip()
        with self.assertRaisesRegex(ValueError, "outside the mod folder"):
            open_mod(self.archive, self.mods, self.validate)
        self.assertEqual(list(self.mods.iterdir()), [])

    def test_missing_gltf_buffer_is_reported(self):
        self.files["scripts/main.gd"] = (
            'extends "base.gd"\nconst MODEL = preload("../model.gltf")\n'
        )
        self.files["model.gltf"] = json.dumps(
            {
                "asset": {"version": "2.0"},
                "buffers": [{"uri": "absent.bin", "byteLength": 8}],
            }
        )
        self.write_zip()
        with self.assertRaisesRegex(ValueError, "absent.bin"):
            open_mod(self.archive, self.mods, self.validate)
        self.assertEqual(list(self.mods.iterdir()), [])

    def test_named_dynamic_resource_includes_its_nested_dependencies(self):
        manifest = json.loads(self.files["mod.json"])
        manifest["resources"] = {"paint/alarm": {"path": "materials/paint.tres"}}
        self.files["mod.json"] = json.dumps(manifest)
        self.files["scripts/main.gd"] = 'extends "base.gd"\n'
        self.write_zip()
        workspace = open_mod(self.archive, self.mods, self.validate)
        self.assertTrue((workspace / "materials/paint.png").is_file())
        self.files.pop("materials/paint.png")
        self.write_zip()
        with self.assertRaisesRegex(ValueError, "dependency is missing"):
            open_mod(self.archive, self.mods, self.validate)
        self.assertEqual(list(self.mods.iterdir()), [workspace])

    def test_cli_supplies_the_real_validator(self):
        self.files.pop("scripts/base.gd")
        self.write_zip()
        result = subprocess.run(
            [
                sys.executable,
                str(REPOSITORY / "tools/import_godot_mod.py"),
                str(self.archive),
                str(self.mods),
                "--godot",
                str(GODOT),
                "--project",
                str(PROJECT),
            ],
            capture_output=True,
            text=True,
            check=False,
            timeout=100,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("scripts/base.gd", result.stderr)
        self.assertEqual(result.stdout, "")
        self.assertEqual(list(self.mods.iterdir()), [])

    def test_cli_accepts_relative_workspace_paths(self):
        self.write_zip()
        result = subprocess.run(
            [
                sys.executable,
                str(REPOSITORY / "tools/import_godot_mod.py"),
                self.archive.name,
                "mods",
                "--godot",
                str(GODOT),
                "--project",
                str(PROJECT),
            ],
            cwd=self.root,
            capture_output=True,
            text=True,
            check=False,
            timeout=100,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(Path(json.loads(result.stdout)["path"]).is_absolute())
