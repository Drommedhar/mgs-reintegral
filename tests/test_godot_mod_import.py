import json
import tempfile
import unittest
import zipfile
from pathlib import Path

from tools.import_godot_mod import open_mod


class ModWorkspaceImport(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.archive = self.root / "lighting.zip"
        self.mods = self.root / "mods"

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
        workspace = open_mod(self.archive, self.mods)
        (workspace / "stages/map.tscn").write_text("edited", encoding="utf-8")
        self.assertEqual(open_mod(self.archive, self.mods), workspace)
        self.assertEqual((workspace / "stages/map.tscn").read_text(), "edited")
        self.assertEqual(self.archive.read_bytes(), original)

    def test_new_revision_gets_its_own_workspace(self):
        self.write()
        first = open_mod(self.archive, self.mods)
        self.write({"authored.txt": "new"})
        self.assertNotEqual(open_mod(self.archive, self.mods), first)

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
                    open_mod(self.archive, self.mods)
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
            open_mod(self.archive, self.mods)

    def test_file_directory_conflict_is_atomic(self):
        self.write({"conflict": "file", "conflict/child": "nested"})
        with self.assertRaises(OSError):
            open_mod(self.archive, self.mods)
        self.assertEqual(list(self.mods.iterdir()), [])

    def test_missing_local_manifest_is_not_silent_success(self):
        self.write()
        workspace = open_mod(self.archive, self.mods)
        (workspace / "mod.json").unlink()
        with self.assertRaises(ValueError):
            open_mod(self.archive, self.mods)
