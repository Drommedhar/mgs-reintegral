import hashlib
import json
import shutil
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import Mock

from tools.import_godot_mod import open_mod


class ModWorkspaceImport(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.archive = self.root / "lighting.zip"
        self.mods = self.root / "mods"
        self.validate = Mock()

    def write(self, files=None):
        manifest = {
            "schema": 1,
            "id": "test.lighting",
            "stages": {"s00a": {"scene": "stages/map.tscn"}},
        }
        with zipfile.ZipFile(self.archive, "w") as archive:
            archive.writestr("mod.json", json.dumps(manifest))
            archive.writestr(
                "stages/map.tscn",
                '[gd_scene format=3]\n[node name="map" type="Node3D"]\n',
            )
            for name, contents in (files or {}).items():
                entry = zipfile.ZipInfo()
                entry.filename = name
                archive.writestr(entry, contents)

    def test_reopening_keeps_local_edits_and_original_zip(self):
        self.write()
        original = self.archive.read_bytes()
        workspace = open_mod(self.archive, self.mods, self.validate)
        (workspace / "stages/map.tscn").write_text("edited", encoding="utf-8")
        self.assertEqual(open_mod(self.archive, self.mods, self.validate), workspace)
        self.assertEqual((workspace / "stages/map.tscn").read_text(), "edited")
        self.assertEqual(self.archive.read_bytes(), original)

    def test_new_revision_gets_its_own_workspace(self):
        self.write()
        first = open_mod(self.archive, self.mods, self.validate)
        self.write({"authored.txt": "new"})
        self.assertNotEqual(open_mod(self.archive, self.mods, self.validate), first)

    def test_dependency_failure_leaves_no_workspace_or_changed_archive(self):
        self.write()
        original = self.archive.read_bytes()
        self.validate.side_effect = ValueError("Missing nested material")
        with self.assertRaisesRegex(ValueError, "Missing nested material"):
            open_mod(self.archive, self.mods, self.validate)
        self.assertEqual(list(self.mods.iterdir()), [])
        self.assertEqual(self.archive.read_bytes(), original)

    def test_resuming_validates_archive_without_touching_local_edits(self):
        self.write()
        workspace = open_mod(self.archive, self.mods, self.validate)
        scene = workspace / "stages/map.tscn"
        scene.write_text("unsent edits", encoding="utf-8")

        def reject(staging):
            self.assertNotEqual(staging, workspace)
            self.assertIn('[node name="map"', (staging / "stages/map.tscn").read_text())
            raise ValueError("Missing nested material")

        self.validate.side_effect = reject
        with self.assertRaisesRegex(ValueError, "Missing nested material"):
            open_mod(self.archive, self.mods, self.validate)
        self.assertEqual(scene.read_text(), "unsent edits")
        self.assertEqual(list(self.mods.iterdir()), [workspace])

    def test_extension_descriptor_path_must_exist_and_be_a_string(self):
        for entry in [{"path": "absent.gdextension"}, {"path": []}, None]:
            with self.subTest(entry=entry):
                with zipfile.ZipFile(self.archive, "w") as archive:
                    archive.writestr(
                        "mod.json",
                        json.dumps(
                            {"schema": 1, "id": "test.extension", "extensions": [entry]}
                        ),
                    )
                with self.assertRaisesRegex(ValueError, "extension descriptor"):
                    open_mod(self.archive, self.mods, self.validate)
                self.validate.assert_not_called()
                self.assertFalse(self.mods.exists())

    def remember_export(self, workspace):
        (workspace / ".editor-workspace.json").write_text(
            json.dumps(
                {
                    "schema": 1,
                    "id": "test.lighting",
                    "export_path": str(self.archive.resolve()),
                    "export_sha256": hashlib.sha256(
                        self.archive.read_bytes()
                    ).hexdigest(),
                }
            ),
            encoding="utf-8",
        )

    def test_reexport_reopens_same_workspace_and_preserves_newer_local_edits(self):
        self.write()
        workspace = open_mod(self.archive, self.mods, self.validate)
        self.write({"custom.txt": "exported revision"})
        self.remember_export(workspace)
        scene = workspace / "stages/map.tscn"
        scene.write_text("newer unsent edits", encoding="utf-8")
        self.assertEqual(open_mod(self.archive, self.mods, self.validate), workspace)
        self.assertEqual(scene.read_text(), "newer unsent edits")

    def test_external_zip_revision_does_not_overwrite_current_workspace(self):
        self.write()
        workspace = open_mod(self.archive, self.mods, self.validate)
        self.remember_export(workspace)
        self.write({"custom.txt": "someone else's revision"})
        self.assertNotEqual(open_mod(self.archive, self.mods, self.validate), workspace)

    def test_conflicting_export_history_is_reported(self):
        self.write()
        workspace = open_mod(self.archive, self.mods, self.validate)
        self.remember_export(workspace)
        shutil.copytree(workspace, self.mods / "duplicate")
        with self.assertRaisesRegex(ValueError, "Multiple workspaces"):
            open_mod(self.archive, self.mods, self.validate)

    def test_archive_cannot_supply_editor_history(self):
        for name in [
            ".editor-source.json",
            ".editor-workspace.json",
            ".EDITOR-WORKSPACE.JSON",
        ]:
            with self.subTest(name=name):
                self.write({name: "{}"})
                with self.assertRaisesRegex(ValueError, "editor-local"):
                    open_mod(self.archive, self.mods, self.validate)
                self.assertFalse(self.mods.exists())

    def test_unsafe_paths_and_case_collisions_leave_no_workspace(self):
        for path in [
            "../escape",
            "/absolute",
            "C:/absolute",
            "stages\\escape",
            "NUL.txt",
            "stages/MAP.tscn",
        ]:
            with self.subTest(path=path):
                self.write({path: "bad"})
                with self.assertRaises(ValueError):
                    open_mod(self.archive, self.mods, self.validate)
                self.assertFalse(self.mods.exists())

    def test_missing_scene_is_rejected(self):
        with zipfile.ZipFile(self.archive, "w") as archive:
            archive.writestr(
                "mod.json",
                json.dumps(
                    {
                        "schema": 1,
                        "id": "broken",
                        "stages": {"s00a": {"scene": "missing.tscn"}},
                    }
                ),
            )
        with self.assertRaisesRegex(ValueError, "Missing mod resource"):
            open_mod(self.archive, self.mods, self.validate)

    def test_file_directory_conflict_is_atomic(self):
        self.write({"conflict": "file", "conflict/child": "nested"})
        with self.assertRaises(OSError):
            open_mod(self.archive, self.mods, self.validate)
        self.assertEqual(list(self.mods.iterdir()), [])

    def test_missing_effect_depth_shader_is_rejected(self):
        manifest = {
            "schema": 1,
            "id": "test.effect",
            "effects": {
                "mgs/effects/snow": {
                    "material": "snow.tres",
                    "depth_shader": "missing.gdshader",
                }
            },
        }
        with zipfile.ZipFile(self.archive, "w") as archive:
            archive.writestr("mod.json", json.dumps(manifest))
            archive.writestr(
                "snow.tres", '[gd_resource type="ShaderMaterial" format=3]'
            )
        with self.assertRaisesRegex(ValueError, "Missing mod resource"):
            open_mod(self.archive, self.mods, self.validate)
        self.assertFalse(self.mods.exists())

    def test_missing_local_manifest_is_not_silent_success(self):
        self.write()
        workspace = open_mod(self.archive, self.mods, self.validate)
        (workspace / "mod.json").unlink()
        with self.assertRaises(ValueError):
            open_mod(self.archive, self.mods, self.validate)

    def test_missing_postprocess_effect_is_rejected(self):
        manifest = {
            "schema": 1,
            "id": "test.vision",
            "postprocess": {"night_vision": {"effect": "missing.tres"}},
        }
        with zipfile.ZipFile(self.archive, "w") as archive:
            archive.writestr("mod.json", json.dumps(manifest))
        with self.assertRaisesRegex(ValueError, "Missing mod resource"):
            open_mod(self.archive, self.mods, self.validate)
        self.assertFalse(self.mods.exists())

    def test_ui_scene_dependency_is_required_and_editable_after_reopen(self):
        manifest = {
            "schema": 1,
            "id": "test.goggles",
            "ui": {"goggles": {"scene": "ui/goggles.tscn"}},
        }
        with zipfile.ZipFile(self.archive, "w") as archive:
            archive.writestr("mod.json", json.dumps(manifest))
        with self.assertRaisesRegex(ValueError, "Missing"):
            open_mod(self.archive, self.mods, self.validate)
        self.assertFalse(self.mods.exists())
        with zipfile.ZipFile(self.archive, "a") as archive:
            archive.writestr(
                "ui/goggles.tscn",
                '[gd_scene format=3]\n[node name="Goggles" type="Control"]\n',
            )
        original = self.archive.read_bytes()
        workspace = open_mod(self.archive, self.mods, self.validate)
        scene = workspace / "ui/goggles.tscn"
        scene.write_text("custom UI", encoding="utf-8")
        self.assertEqual(open_mod(self.archive, self.mods, self.validate), workspace)
        self.assertEqual(scene.read_text(encoding="utf-8"), "custom UI")
        self.assertEqual(self.archive.read_bytes(), original)
