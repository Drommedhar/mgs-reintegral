"""Execute the workflow's PowerShell guards and publication with a fake gh."""

import json
import os
import re
import shutil
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / ".github/workflows/godot.yml"
ASSETS = (
    "reintegral-0.3.0-windows-x86.zip",
    "reintegral-sdk-0.3.0-windows-x86.zip",
    "reintegral-0.3.0-symbols.zip",
    "reintegral-0.3.0-SHA256SUMS.txt",
)


def step_script(name):
    step = (
        WORKFLOW.read_text(encoding="utf-8")
        .split(f"      - name: {name}\n", 1)[1]
        .split("\n      - ", 1)[0]
    )
    block = re.search(r"        run: \|\n((?:          [^\n]*(?:\n|$))+)", step)
    if block is None:
        raise ValueError("Missing workflow script: " + name)
    return textwrap.dedent(block[1])


class ReleaseWorkflowTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="release workflow ü ")
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.env = os.environ | {
            "RELEASE_VERSION": "0.3.0",
            "PUBLISH_RELEASE": "true",
            "GITHUB_REF": "refs/heads/main",
            "GITHUB_REPOSITORY": "fixture/offline",
            "GITHUB_SHA": "a" * 40,
            "GH_TOKEN": "offline-test",
            "FAKE_RELEASE": "",
            "FAKE_TAG": "",
            "FAKE_FAILURE": "",
        }
        packages = self.root / "build/packages"
        packages.mkdir(parents=True)
        for name in ASSETS:
            (packages / name).write_text("fixture", encoding="ascii")

    def run_step(self, name):
        script = self.root / "step.ps1"
        script.write_text(
            r"""$ErrorActionPreference = 'Stop'
function gh {
    ConvertTo-Json -InputObject @($args) -Compress | Add-Content -LiteralPath calls.jsonl
    $global:LASTEXITCODE = 0
    if ($env:FAKE_FAILURE -eq $args[0] -or $env:FAKE_FAILURE -eq $args[1]) {
        $global:LASTEXITCODE = 1
        return
    }
    if ($args[0] -eq 'api') {
        if ($args[1].EndsWith('/releases')) { $env:FAKE_RELEASE }
        else { $env:FAKE_TAG }
    }
}
"""
            + step_script(name),
            encoding="utf-8",
        )
        result = subprocess.run(
            [shutil.which("pwsh"), "-NoProfile", "-File", str(script)],
            cwd=self.root,
            env=self.env,
            text=True,
            capture_output=True,
            check=False,
            timeout=30,
        )
        log = self.root / "calls.jsonl"
        calls = (
            [json.loads(line) for line in log.read_text().splitlines()]
            if log.exists()
            else []
        )
        return result, calls

    def validate(self):
        return self.run_step("Validate release request")

    def publish(self):
        return self.run_step("Publish stable release after validation")

    def test_new_stable_release_on_main_is_allowed(self):
        result, calls = self.validate()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(calls), 2)
        self.assertTrue(all(call[0] == "api" for call in calls))

    def test_publication_from_feature_branch_is_rejected_before_github(self):
        self.env["GITHUB_REF"] = "refs/heads/feature/work"
        result, calls = self.validate()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Publish releases from main", result.stderr)
        self.assertEqual(calls, [])

    def test_branch_build_without_publication_does_not_contact_github(self):
        self.env.update(GITHUB_REF="refs/heads/feature/work", PUBLISH_RELEASE="false")
        result, calls = self.validate()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls, [])

    def test_prerelease_versions_are_rejected(self):
        for version in ("0.3.0-alpha.1", "0.3.0-rc.1", "0.3", "v0.3.0"):
            with self.subTest(version=version):
                self.env["RELEASE_VERSION"] = version
                result, calls = self.validate()
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(calls, [])

    def test_existing_release_is_rejected(self):
        self.env["FAKE_RELEASE"] = "v0.3.0"
        result, _ = self.validate()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("release already exists", result.stderr)

    def test_existing_tag_is_rejected(self):
        self.env["FAKE_TAG"] = "refs/tags/v0.3.0"
        result, _ = self.validate()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("tag already exists", result.stderr)

    def test_lookup_failure_is_not_treated_as_an_unused_version(self):
        self.env["FAKE_FAILURE"] = "api"
        result, _ = self.validate()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Cannot inspect existing releases", result.stderr)

    def test_uploads_all_downloads_then_publishes_stable_latest(self):
        result, calls = self.publish()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(calls), 2)
        create, publish = calls
        self.assertEqual(create[:3], ["release", "create", "v0.3.0"])
        self.assertEqual({Path(path).name for path in create[3:7]}, set(ASSETS))
        self.assertEqual(create[create.index("--target") + 1], self.env["GITHUB_SHA"])
        self.assertIn("--draft", create)
        self.assertIn("--prerelease=false", create)
        self.assertEqual(publish[:3], ["release", "edit", "v0.3.0"])
        self.assertTrue(
            {"--draft=false", "--prerelease=false", "--latest"} <= set(publish)
        )

    def test_missing_sdk_prevents_any_release_creation(self):
        (self.root / "build/packages" / ASSETS[1]).unlink()
        result, calls = self.publish()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Missing release asset", result.stderr)
        self.assertEqual(calls, [])

    def test_failed_upload_does_not_publish_the_draft(self):
        self.env["FAKE_FAILURE"] = "create"
        result, calls = self.publish()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0][:2], ["release", "create"])
        self.assertIn("partial release remains a draft", result.stderr)
