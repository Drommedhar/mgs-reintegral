"""Exercise source-build renderer installation without compiling the native host."""

import hashlib
import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PWSH = shutil.which("pwsh")


@unittest.skipUnless(PWSH, "PowerShell 7 source build")
class BuildRendererTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="source build ü ")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        for directory in ("tools", ".venv/Scripts", "docs/data", "legacy/licenses"):
            (self.root / directory).mkdir(parents=True)
        for name in ("build.ps1", "prepare-build-renderers.ps1"):
            shutil.copyfile(ROOT / "tools" / name, self.root / "tools" / name)
        target = self.root / "renderers/legacy/renderer.json"
        target.parent.mkdir(parents=True)
        shutil.copyfile(ROOT / "renderers/legacy/renderer.json", target)
        (self.root / "requirements.txt").write_bytes(b"")
        (self.root / ".venv/requirements.sha256").write_text(
            hashlib.sha256(b"").hexdigest()
        )
        (self.root / ".venv/Scripts/python.exe").touch()
        (self.root / "sources.lock.json").write_text('{"repositories": []}')
        self.legacy = b"preserved legacy fixture"
        (self.root / "legacy/mgs-integral-native.exe").write_bytes(self.legacy)
        (self.root / "legacy/licenses/MPL-2.0.txt").write_text("license fixture")
        (self.root / "legacy-source.zip").write_bytes(b"source fixture")
        (self.root / "docs/data/godot_sdk_baseline.json").write_text(
            json.dumps(
                {
                    "legacy_archive_members": {
                        "reintegral-0.2.0-alpha.1-windows-x86/mgs-integral-native.exe": hashlib.sha256(
                            self.legacy
                        ).hexdigest()
                    }
                }
            )
        )
        self.write_script(
            "toolchain.ps1",
            "[pscustomobject]@{ CMake = Join-Path $PSScriptRoot 'fake-cmake.ps1'; "
            "Ninja = 'unused'; Clang = 'unused'; ClangCxx = 'unused' }",
        )
        self.write_script(
            "fake-cmake.ps1",
            """
if ($args[0] -eq '--build') {
    foreach ($name in @('RE-INTEGRAL.exe', 'mgs-integral-native.exe')) {
        Set-Content -LiteralPath (Join-Path $args[1] $name) -Value 'compiled fixture'
    }
} else {
    $build = $args[[Array]::IndexOf($args, '-B') + 1]
    New-Item -ItemType Directory -Path $build -Force | Out-Null
    $backend = if ($args -match '-DMGS_RENDERER_MODULE=.+') { 'godot' } else { 'native' }
    @{ id = $backend; backend = $backend } | ConvertTo-Json |
        Set-Content -LiteralPath (Join-Path $build 'renderer.json')
}
$global:LASTEXITCODE = 0
""",
        )
        self.write_script(
            "prepare-godot.ps1",
            "Set-Content -LiteralPath (Join-Path $PSScriptRoot '../godot-prepared') -Value 'yes'",
        )
        self.write_script(
            "prepare-sdk-tools.ps1",
            "@{ legacy = Join-Path $PSScriptRoot '../legacy'; "
            "legacySource = Join-Path $PSScriptRoot '../legacy-source.zip'; "
            "godotNotices = Join-Path $PSScriptRoot '../legacy/licenses' }",
        )
        for arguments in (
            ("init", "--quiet"),
            (
                "-c",
                "user.name=Build test",
                "-c",
                "user.email=build@example.invalid",
                "-c",
                "commit.gpgsign=false",
                "commit",
                "--quiet",
                "--allow-empty",
                "-m",
                "fixture",
            ),
        ):
            subprocess.run(
                ["git", "-C", str(self.root), *arguments],
                check=True,
                capture_output=True,
            )

    def write_script(self, name, content):
        (self.root / "tools" / name).write_text(content, encoding="utf-8")

    def build(self, *arguments, godot=True):
        command = [
            PWSH,
            "-NoProfile",
            "-File",
            str(self.root / "tools/build.ps1"),
            "-Configuration",
            "RelWithDebInfo",
            "-BuildDirectory",
            "build/native",
            "-Version",
            "0.3.0",
        ]
        if godot:
            command += ["-RendererModule", str(self.root / "tools")]
        return subprocess.run(
            command + list(arguments),
            check=False,
            cwd=self.root,
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=30,
        )

    def assert_success(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_full_godot_build_installs_both_renderers_and_repairs_missing_payload(self):
        for _ in range(2):
            self.assert_success(self.build())
            build = self.root / "build/native"
            self.assertEqual(
                json.loads((build / "renderer.json").read_text())["backend"], "godot"
            )
            descriptor = build / "renderers/legacy/renderer.json"
            self.assertTrue(
                descriptor.is_file(), "Source build omitted standalone Legacy renderer"
            )
            legacy = json.loads(descriptor.read_text(encoding="utf-8-sig"))
            self.assertEqual(legacy["id"], "legacy")
            executable = descriptor.parent / legacy["executable"]
            self.assertEqual(executable.read_bytes(), self.legacy)
            self.assertTrue((descriptor.parent / "licenses/MPL-2.0.txt").is_file())
            self.assertEqual(
                (descriptor.parent / "legacy-0.2-mpl-source.zip").read_bytes(),
                b"source fixture",
            )
            self.assertTrue((self.root / "godot-prepared").is_file())
            executable.unlink()

    def test_godot_preparation_failure_fails_the_build(self):
        self.write_script("prepare-godot.ps1", "throw 'Godot download failed'")
        result = self.build()
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Godot download failed", result.stdout + result.stderr)

    def test_configure_only_does_not_install_renderers(self):
        self.assert_success(self.build("-ConfigureOnly"))
        self.assertFalse((self.root / "godot-prepared").exists())

    def test_targeted_test_build_does_not_install_renderers(self):
        self.assert_success(self.build("-Target", "mgs_godot_scene_test"))
        self.assertFalse((self.root / "godot-prepared").exists())

    def test_native_build_does_not_install_godot_or_replace_its_renderer(self):
        self.assert_success(self.build(godot=False))
        self.assertFalse((self.root / "godot-prepared").exists())
        self.assertFalse((self.root / "build/native/renderers/legacy").exists())

    def test_modified_legacy_is_rejected_before_installation(self):
        (self.root / "legacy/mgs-integral-native.exe").write_bytes(b"changed")
        result = self.build()
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Legacy executable differs", result.stdout + result.stderr)
        self.assertFalse(
            (self.root / "build/native/renderers/legacy/renderer.json").exists()
        )


if __name__ == "__main__":
    unittest.main()
