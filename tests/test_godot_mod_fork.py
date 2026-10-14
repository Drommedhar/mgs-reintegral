import json
import tempfile
import unittest
from pathlib import Path

from tools.fork_godot_mod import fork_mod


class ModWorkspaceFork(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.project = Path(temporary.name)
        self.source = self.project / "mods" / "original"
        self.source.mkdir(parents=True)
        self.destination = self.project / "mods" / "copy"
        self.manifest = {
            "schema": 1,
            "id": "test.original",
            "version": "1.4",
            "stages": {"s00a": {"scene": "map.tscn"}},
        }
        self.write("mod.json", json.dumps(self.manifest))

    def write(self, name, text):
        target = self.source / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")

    def fork(self):
        return fork_mod(
            self.source, self.destination, self.project, "test.copy", "Custom copy"
        )

    def test_copy_retains_drafts_and_relocates_custom_resources(self):
        scene = '[gd_scene format=3 uid="uid://original"]\n[ext_resource path="res://mods/original/material.tres" uid="uid://material" id="1"]'
        self.write("map.tscn", scene)
        self.write("material.tres", '[gd_resource type="StandardMaterial3D" format=3]')
        self.write("drafts/unassigned.txt", "still editing")
        self.write(
            "scripts/helper.gd",
            'extends Node\nconst M = preload("res://mods/original/material.tres")',
        )
        self.assertEqual(self.fork(), self.destination)
        copy = json.loads((self.destination / "mod.json").read_text())
        self.assertEqual(
            (copy["id"], copy["name"], copy["version"]),
            ("test.copy", "Custom copy", "1.4"),
        )
        self.assertEqual(copy["stages"], self.manifest["stages"])
        self.assertEqual((self.source / "map.tscn").read_text(), scene)
        self.assertEqual(
            json.loads((self.source / "mod.json").read_text()), self.manifest
        )
        self.assertEqual(
            (self.destination / "drafts/unassigned.txt").read_text(), "still editing"
        )
        for name in ["map.tscn", "scripts/helper.gd"]:
            text = (self.destination / name).read_text()
            self.assertIn("res://mods/copy/material.tres", text)
            self.assertNotIn("res://mods/original/", text)
            self.assertNotIn("uid://", text)

    def test_copy_starts_without_export_history_and_generated_ids(self):
        for name in [
            ".editor-source.json",
            ".editor-workspace.json",
            ".godot/cache",
            "draft.gd.uid",
            "image.png.import",
        ]:
            self.write(name, "local-only")
        self.fork()
        self.assertEqual({p.name for p in self.destination.iterdir()}, {"mod.json"})

    def test_new_identity_and_folder_are_required(self):
        with self.assertRaisesRegex(ValueError, "different mod ID"):
            fork_mod(
                self.source, self.destination, self.project, "test.original", "Copy"
            )
        self.destination.mkdir()
        with self.assertRaisesRegex(ValueError, "new workspace folder"):
            self.fork()
        self.assertEqual(list(self.destination.iterdir()), [])

    def test_malformed_manifest_leaves_no_copy(self):
        self.write("mod.json", "[]")
        with self.assertRaisesRegex(ValueError, "manifest"):
            self.fork()
        self.assertFalse(self.destination.exists())
