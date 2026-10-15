"""SDK packaging must reject copied originals and unlisted staging files."""

import hashlib
import io
import json
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch

from tools.sdk_package_audit import (
    audit,
    inspect_archive,
    inspect_resource,
    known_original_hashes,
)


def archive_of(name, data):
    stream = io.BytesIO()
    with zipfile.ZipFile(stream, "w") as archive:
        archive.writestr(name, data)
    return stream.getvalue()


class SdkPackageTests(unittest.TestCase):
    def test_baseline_detects_original_without_local_disc_catalogs(self):
        self.assertGreater(len(known_original_hashes()), 33000)
        original = b"synthetic fingerprint fixture"
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            contents = archive_of("nested.zip", archive_of("renamed.dat", original))
            (root / "source.zip").write_bytes(contents)
            inventory = {"source.zip": hashlib.sha256(contents).hexdigest()}
            with (
                patch(
                    "tools.sdk_package_audit.known_original_hashes",
                    return_value={hashlib.sha256(original).hexdigest()},
                ),
                self.assertRaisesRegex(ValueError, "Original-content copy"),
            ):
                audit(root, inventory)

    def test_downloaded_tools_cannot_enter_release_archive(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            path = root / ".tools/godot/engine.exe"
            path.parent.mkdir(parents=True)
            path.write_bytes(b"tool fixture")
            with self.assertRaisesRegex(ValueError, "must not be bundled"):
                audit(
                    root,
                    {
                        path.relative_to(root).as_posix(): hashlib.sha256(
                            path.read_bytes()
                        ).hexdigest()
                    },
                )

    def test_loose_editor_resources_and_embedded_images_cannot_ship(self):
        custom = '[gd_resource type="StandardMaterial3D" format=3]\n'
        inspect_resource("examples/named_resources/amber.tres", custom)
        inspect_resource(
            "map_environment.tres", '[gd_resource type="Environment" format=3]\n'
        )
        with self.assertRaisesRegex(ValueError, "unreviewed"):
            inspect_resource("new_standard_material_3d.tres", custom)
        with self.assertRaisesRegex(ValueError, "image data"):
            inspect_resource(
                "examples/named_resources/amber.tres",
                custom + "data = PackedByteArray(1, 2, 3)",
            )

    def test_original_cannot_hide_inside_tool_or_source_archives(self):
        original = b"synthetic original asset"
        originals = {hashlib.sha256(original).hexdigest()}
        contents = archive_of("renamed.dll", original)
        nested = archive_of("source.zip", contents)
        with self.assertRaisesRegex(ValueError, "Original-content copy"):
            inspect_archive(nested, "tools.zip", originals)
        inspect_archive(archive_of("code.py", b"custom code"), "tools.zip", originals)

    def test_inventory_and_original_hashes_are_both_enforced(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            package = root / "sdk"
            package.mkdir()
            local = root / "local"
            original = b"synthetic original texture"
            digest = hashlib.sha256(original).hexdigest()
            catalog = {
                "assets": {
                    "original": {
                        "sha256": digest,
                        "preparedFiles": {"texture.png": digest},
                    }
                }
            }
            for name in ("godot-content", "godot-content-disc2"):
                directory = local / name
                directory.mkdir(parents=True)
                (directory / "catalog.json").write_text(
                    json.dumps(catalog), encoding="utf-8"
                )
            (package / "engine.exe").write_bytes(b"custom fixture")
            inventory = {"engine.exe": hashlib.sha256(b"custom fixture").hexdigest()}
            audit(package, inventory, local)
            font_path = "renderers/godot/project/.generated/legacy-debug-font.bin"
            fake_font = package / font_path
            fake_font.parent.mkdir(parents=True)
            fake_font.write_bytes(b"unreviewed font")
            with self.assertRaisesRegex(ValueError, "unreviewed binary"):
                audit(
                    package,
                    inventory
                    | {font_path: hashlib.sha256(fake_font.read_bytes()).hexdigest()},
                    local,
                )
            fake_font.unlink()
            (package / "unexpected.txt").write_bytes(b"not in package list")
            with self.assertRaisesRegex(ValueError, "unlisted"):
                audit(package, inventory, local)
            (package / "unexpected.txt").unlink()
            (package / "engine.exe").write_bytes(original)
            with self.assertRaisesRegex(ValueError, "original-content copy"):
                audit(package, {"engine.exe": digest}, local)
