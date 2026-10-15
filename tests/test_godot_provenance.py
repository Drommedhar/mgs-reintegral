"""Prepared identities remain stable while dependency revisions detect edits."""

import json
import tempfile
import unittest
from pathlib import Path

from tools.godot_assets.provenance import stamp_assets


class PreparedProvenance(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        (self.root / "map").mkdir()
        (self.root / "shared.png").write_bytes(b"texture")
        self.model = self.root / "map/model.gltf"
        self.model.write_text(json.dumps({"images": [{"uri": "../shared.png"}]}))
        self.assets = {
            "original/model.k": {
                "kind": "model",
                "path": "map/model.gltf",
                "sha256": "a" * 64,
            }
        }

    def test_dependency_change_preserves_source_identity(self):
        stamp_assets(self.root, self.assets)
        before = dict(self.assets["original/model.k"])
        (self.root / "shared.png").write_bytes(b"changed texture")
        stamp_assets(self.root, self.assets)
        after = self.assets["original/model.k"]
        self.assertEqual(before["contentId"], after["contentId"])
        self.assertNotEqual(before["preparedRevision"], after["preparedRevision"])
        self.assertEqual(set(after["preparedFiles"]), {"map/model.gltf", "shared.png"})

    def test_source_revision_and_namespace_are_distinct(self):
        stamp_assets(self.root, self.assets)
        before = self.assets["original/model.k"]["contentId"]
        self.assets["original/model.k"]["sha256"] = "b" * 64
        stamp_assets(self.root, self.assets)
        self.assertNotEqual(before, self.assets["original/model.k"]["contentId"])
        self.assets["another/model.k"] = dict(self.assets["original/model.k"])
        stamp_assets(self.root, self.assets)
        self.assertNotEqual(
            self.assets["original/model.k"]["contentId"],
            self.assets["another/model.k"]["contentId"],
        )

    def test_missing_or_external_dependency_does_not_partially_stamp(self):
        for uri in ["missing.png", "../../outside.png", "https://example.test/a.png"]:
            self.model.write_text(json.dumps({"images": [{"uri": uri}]}))
            with self.assertRaises((ValueError, FileNotFoundError)):
                stamp_assets(self.root, self.assets)
            self.assertNotIn("contentId", self.assets["original/model.k"])

    def test_texture_mask_is_part_of_revision(self):
        (self.root / "shared.stp.png").write_bytes(b"mask")
        assets = {
            "texture.p": {"kind": "texture", "path": "shared.png", "sha256": "c" * 64}
        }
        stamp_assets(self.root, assets)
        self.assertEqual(
            set(assets["texture.p"]["preparedFiles"]), {"shared.png", "shared.stp.png"}
        )
