"""Release archives must provide working descriptors for both renderer choices."""

import argparse
import hashlib
import json
import os
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch

from tools.package_godot_sdk import stable_version
from tools.verify_godot_package import NativeProbeDirectory, verify


class ReleasePackageTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="stable package ")
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name) / "reintegral-sdk-0.3.0-windows-x86.zip"
        self.metadata = {
            "kind": "sdk",
            "version": "0.3.0",
            "channel": "stable",
            "sourceCommit": "a" * 40,
            "nativeBuild": "RE:INTEGRAL 0.3.0 (aaaaaaaaaaaa)",
        }
        self.godot = {
            "id": "godot",
            "backend": "godot",
            "version": "0.3.0",
            "executable": "build/windows-x86-godot/mgs-integral-native.exe",
            "godotProject": "renderers/godot/project",
        }
        self.legacy = {
            "id": "legacy",
            "backend": "native",
            "executable": "mgs-integral-native.exe",
        }
        self.files = dict.fromkeys(
            (
                "RE-INTEGRAL.exe",
                "Prepare.cmd",
                "Play.cmd",
                "Editor.cmd",
                "build/windows-x86-godot/mgs-integral-native.exe",
                "renderers/legacy/mgs-integral-native.exe",
                "renderers/godot/project/project.godot",
                "renderers/godot/project/addons/mgs_editor/plugin.cfg",
                "renderers/godot/sdk/CMakeLists.txt",
                "renderers/godot/sdk/example_mod.cpp",
            ),
            b"fixture",
        )

    def verify_fixture(self):
        files = self.files | {
            "sdk.json": json.dumps(self.metadata).encode(),
            "renderer.json": json.dumps(self.godot).encode(),
            "renderers/legacy/renderer.json": json.dumps(self.legacy).encode(),
        }
        inventory = {
            name: hashlib.sha256(data).hexdigest() for name, data in files.items()
        }
        files["package-files.json"] = json.dumps({"sha256": inventory}).encode()
        with zipfile.ZipFile(self.path, "w") as archive:
            for name, data in files.items():
                archive.writestr(self.path.stem + "/" + name, data)
        with patch(
            "tools.verify_godot_package.subprocess.check_output",
            return_value=self.metadata["nativeBuild"],
        ):
            return verify(self.path)

    def test_stable_sdk_and_game_include_both_renderers(self):
        self.assertEqual(self.verify_fixture()["channel"], "stable")
        self.metadata["kind"] = "game"
        self.files.pop("Editor.cmd")
        self.assertEqual(self.verify_fixture()["kind"], "game")

    def test_missing_legacy_executable_is_rejected_even_with_valid_inventory(self):
        self.files.pop("renderers/legacy/mgs-integral-native.exe")
        with self.assertRaisesRegex(ValueError, "Missing renderer executable"):
            self.verify_fixture()

    def test_unavailable_legacy_descriptor_is_rejected(self):
        self.legacy["executable"] = "missing.exe"
        with self.assertRaisesRegex(ValueError, "Missing renderer executable"):
            self.verify_fixture()

    def test_sdk_without_editor_plugin_is_rejected(self):
        self.files.pop("renderers/godot/project/addons/mgs_editor/plugin.cfg")
        with self.assertRaisesRegex(ValueError, "Missing release payload"):
            self.verify_fixture()

    def test_alpha_channel_cannot_be_relabelled_as_stable(self):
        self.metadata["channel"] = "alpha"
        with self.assertRaisesRegex(ValueError, "stable version and channel"):
            self.verify_fixture()

    def test_renderer_version_must_match_release(self):
        self.godot["version"] = "0.3.0-alpha.1"
        with self.assertRaisesRegex(ValueError, "renderer version differs"):
            self.verify_fixture()

    def test_packager_rejects_prerelease_version_before_staging(self):
        self.assertEqual(stable_version("0.3.0"), "0.3.0")
        with self.assertRaises(argparse.ArgumentTypeError):
            stable_version("0.3.0-alpha.1")

    def test_temporary_windows_lock_does_not_fail_valid_package(self):
        unlink = os.unlink
        failures = []

        def temporarily_locked(path, *args, **kwargs):
            if Path(path).name == "mgs-integral-native.exe" and len(failures) < 3:
                error = PermissionError(13, "File is in use", str(path))
                error.winerror = 32
                failures.append(error)
                raise error
            return unlink(path, *args, **kwargs)

        with (
            patch("tempfile.tempdir", self.directory.name),
            patch("os.unlink", side_effect=temporarily_locked),
        ):
            self.assertEqual(self.verify_fixture()["version"], "0.3.0")
        self.assertEqual(len(failures), 3)

    def test_persistent_windows_lock_is_still_fatal(self):
        error = PermissionError(13, "File is in use")
        error.winerror = 32
        directory = NativeProbeDirectory(dir=self.directory.name)
        with (
            patch("tempfile.TemporaryDirectory.cleanup", side_effect=error) as cleanup,
            patch("tools.verify_godot_package.time.sleep") as sleep,
            self.assertRaises(PermissionError),
        ):
            directory.cleanup()
        self.assertEqual(cleanup.call_count, 51)
        self.assertEqual(sleep.call_count, 50)
        directory.cleanup()

    def test_other_permission_errors_are_not_retried(self):
        directory = NativeProbeDirectory(dir=self.directory.name)
        with (
            patch("tempfile.TemporaryDirectory.cleanup", side_effect=PermissionError),
            patch("tools.verify_godot_package.time.sleep") as sleep,
            self.assertRaises(PermissionError),
        ):
            directory.cleanup()
        sleep.assert_not_called()
        directory.cleanup()
