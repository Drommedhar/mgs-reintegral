"""Disc identity and coverage accounting using synthetic resources only."""

import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from tests.test_list_assets import stage_fixture
from tools.audit_godot_presentation import inventory


class PresentationInventoryTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.config = self.root / "stages.json"
        self.config.write_text(
            json.dumps({"stages": ["s00a", "missing"]}), encoding="utf-8"
        )
        self.catalog = self.root / "catalog.json"
        source = stage_fixture()
        self.source_hash = hashlib.sha256(source).hexdigest()
        for disc, serial in [(1, "SLPM_862.47"), (2, "SLPM_862.48")]:
            folder = self.root / f"disc{disc}"
            (folder / "MGS").mkdir(parents=True)
            (folder / "MGS/STAGE.DIR").write_bytes(source)
            receipt = {
                "serial": serial,
                "image": {"sha256": str(disc) * 64},
                "files": [{"path": "MGS/STAGE.DIR", "sha256": self.source_hash}],
            }
            (folder / "manifest.json").write_text(json.dumps(receipt), encoding="utf-8")
        self.prepared = {
            "schema": 1,
            "disc": 1,
            "edition": "integral-j",
            "sourceImageSha256": "1" * 64,
            "stageDirSha256": self.source_hash,
            "assets": {"mgs/integral-j/disc1/stage/s00a/1234.p": {}},
        }

    def audit(self):
        self.catalog.write_text(json.dumps(self.prepared), encoding="utf-8")
        return inventory(self.root, self.config, self.catalog)

    def test_catalogue_does_not_imply_cross_disc_or_runtime_coverage(self):
        report = self.audit()
        first, second = [disc["stages"][0] for disc in report["discs"]]
        self.assertTrue(first["prepared_catalog_entry"])
        self.assertFalse(second["prepared_catalog_entry"])
        self.assertEqual(first["presentation_acceptance"], "unverified")
        self.assertEqual(report["configured_missing_from_both_discs"], ["missing"])
        self.assertEqual(
            first["scripts"][0]["sha256"], hashlib.sha256(b"code").hexdigest()
        )
        self.assertNotIn("TEX!", json.dumps(report))
        self.assertEqual(report["summary"]["verified_presentation_entries"], 0)

    def test_receipt_and_catalogue_mismatches_are_rejected(self):
        for field in ["sourceImageSha256", "stageDirSha256"]:
            with self.subTest(field=field):
                original = self.prepared[field]
                self.prepared[field] = "0" * 64
                with self.assertRaisesRegex(ValueError, "catalog"):
                    self.audit()
                self.prepared[field] = original
        source = self.root / "disc2/MGS/STAGE.DIR"
        source.write_bytes(source.read_bytes() + b"changed")
        with self.assertRaisesRegex(ValueError, "import receipt"):
            self.audit()

    def test_no_catalogue_reports_missing_preparation_without_inventing_it(self):
        report = inventory(self.root, self.config, None)
        self.assertEqual(report["summary"]["catalogued_entries"], 0)
        self.assertIsNone(report["prepared_catalog_sha256"])

    def test_inconsistent_asset_namespace_is_rejected(self):
        self.prepared["assets"] = {"mgs/integral-j/disc2/stage/s00a/1234.p": {}}
        with self.assertRaisesRegex(ValueError, "inconsistent asset ID"):
            self.audit()

    def test_multiple_catalogues_keep_disc_provenance_and_acceptance_separate(self):
        self.audit()
        second = self.root / "disc2-catalog.json"
        prepared = dict(self.prepared, disc=2, sourceImageSha256="2" * 64)
        prepared["assets"] = {"mgs/integral-j/disc2/stage/s00a/1234.p": {}}
        second.write_text(json.dumps(prepared), encoding="utf-8")
        report = inventory(self.root, self.config, [second, self.catalog])
        self.assertEqual(report["summary"]["catalogued_entries"], 2)
        self.assertEqual(report["summary"]["verified_presentation_entries"], 0)
        self.assertEqual([item["disc"] for item in report["prepared_catalogs"]], [1, 2])
        for disc in report["discs"]:
            self.assertTrue(disc["stages"][0]["prepared_catalog_entry"])
            self.assertEqual(disc["stages"][0]["presentation_acceptance"], "unverified")
        prepared["sourceImageSha256"] = "1" * 64
        second.write_text(json.dumps(prepared), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "original disc"):
            inventory(self.root, self.config, [self.catalog, second])

    def test_duplicate_disc_catalogues_are_rejected(self):
        self.audit()
        with self.assertRaisesRegex(ValueError, "Duplicate prepared catalog"):
            inventory(self.root, self.config, [self.catalog, self.catalog])


if __name__ == "__main__":
    unittest.main()
