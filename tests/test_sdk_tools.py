"""Exercise pinned downloads through Windows PowerShell without installed tools."""

import functools
import hashlib
import http.server
import json
import os
import shutil
import subprocess
import tempfile
import threading
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WINDOWS_PS = (
    Path(os.environ.get("SystemRoot", "C:/Windows"))
    / "System32/WindowsPowerShell/v1.0/powershell.exe"
)


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *_args):
        pass


@unittest.skipUnless(WINDOWS_PS.is_file(), "Windows PowerShell bootstrap")
class SdkToolTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="sdk tools ")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / "moved SDK ü"
        (self.root / "tools").mkdir(parents=True)
        for name in [
            "sdk-bootstrap.ps1",
            "download-tool.ps1",
            "sdk-paths.ps1",
            "prepare-python.ps1",
            "sdk.ps1",
        ]:
            shutil.copyfile(ROOT / "tools" / name, self.root / "tools" / name)
        self.downloads = Path(self.temporary.name) / "server"
        self.downloads.mkdir()
        handler = functools.partial(QuietHandler, directory=str(self.downloads))
        self.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler)
        thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(self.server.server_close)
        self.addCleanup(self.server.shutdown)
        self.lock = {"sdkTools": {}}
        for name in ["godot", "powershell", "python"]:
            self.make_tool(name, {"tool.exe": name.encode()})
        self.save_lock()

    def make_tool(self, name, files):
        archive = self.downloads / (name + ".zip")
        with zipfile.ZipFile(archive, "w") as output:
            for path, data in files.items():
                output.writestr(path, data)
        self.lock["sdkTools"][name] = {
            "version": "1.0",
            "url": f"http://127.0.0.1:{self.server.server_port}/{archive.name}",
            "sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
            "directory": name,
            "files": {
                path: hashlib.sha256(data).hexdigest()
                for path, data in files.items()
                if ".." not in Path(path).parts
            },
        }

    def save_lock(self):
        (self.root / "sources.lock.json").write_text(json.dumps(self.lock))

    def run_bootstrap(self, action="editor"):
        return self.run_script("sdk-bootstrap.ps1", "-Action", action, "-ToolsOnly")

    def run_script(self, name, *arguments):
        return subprocess.run(
            [
                str(WINDOWS_PS),
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                str(self.root / "tools" / name),
                *arguments,
            ],
            capture_output=True,
            check=False,
            text=True,
            timeout=60,
        )

    def assert_success(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_first_editor_downloads_only_runtime_then_prepare_adds_python(self):
        self.assert_success(self.run_bootstrap())
        self.assertFalse((self.root / ".tools/python").exists())
        self.assert_success(self.run_bootstrap("prepare"))
        self.assertEqual(
            (self.root / ".tools/python/python313._pth").read_bytes(),
            b"python313.zip\n.\n../../tools\n",
        )

    def test_complete_tools_work_without_network(self):
        self.assert_success(self.run_bootstrap("prepare"))
        for entry in self.lock["sdkTools"].values():
            entry["url"] = "http://127.0.0.1:1/offline.zip"
        self.save_lock()
        self.assert_success(self.run_bootstrap("prepare"))

    def test_bad_hash_is_not_installed_and_retry_succeeds(self):
        archive = self.downloads / "powershell.zip"
        valid = archive.read_bytes()
        archive.write_bytes(b"damaged download")
        result = self.run_bootstrap()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("checksum mismatch", result.stderr)
        self.assertFalse((self.root / ".tools/powershell").exists())
        self.assertFalse(list((self.root / ".tools").rglob("*.partial")))
        archive.write_bytes(valid)
        self.assert_success(self.run_bootstrap())

    def test_download_failure_leaves_no_active_tool(self):
        (self.downloads / "powershell.zip").unlink()
        self.assertNotEqual(self.run_bootstrap().returncode, 0)
        self.assertFalse((self.root / ".tools/powershell").exists())
        self.make_tool("powershell", {"tool.exe": b"powershell"})
        self.save_lock()
        self.assert_success(self.run_bootstrap())

    def test_corrupt_installed_tool_is_repaired_from_verified_cache(self):
        self.assert_success(self.run_bootstrap())
        executable = self.root / ".tools/godot/tool.exe"
        executable.write_bytes(b"broken")
        (self.downloads / "godot.zip").unlink()
        self.assert_success(self.run_bootstrap())
        self.assertEqual(executable.read_bytes(), b"godot")

    def test_missing_runtime_dependency_is_repaired_offline(self):
        self.make_tool(
            "powershell", {"tool.exe": b"fixture", "coreclr.dll": b"runtime"}
        )
        self.save_lock()
        self.assert_success(self.run_bootstrap())
        dependency = self.root / ".tools/powershell/coreclr.dll"
        dependency.unlink()
        (self.downloads / "powershell.zip").unlink()
        self.assert_success(self.run_bootstrap())
        self.assertEqual(dependency.read_bytes(), b"runtime")

    def test_editor_python_operation_installs_python_on_demand(self):
        (self.root / "sdk.json").write_text("{}")
        self.assert_success(self.run_bootstrap())
        self.assertFalse((self.root / ".tools/python").exists())
        self.assert_success(self.run_script("prepare-python.ps1"))
        self.assertTrue((self.root / ".tools/python/tool.exe").is_file())

    def test_prepare_accepts_comma_separated_command_arguments(self):
        (self.root / "tools/prepare-godot-content.ps1").write_text(
            "param($Disc, $DiscDirectory, $CueFiles, $Stages)\n"
            "@{disc=$Disc; stages=$Stages; directory=$DiscDirectory} | ConvertTo-Json -Compress | "
            "Add-Content -LiteralPath (Join-Path $PSScriptRoot 'calls.jsonl')\n"
        )
        self.assert_success(
            self.run_script(
                "sdk.ps1",
                "-Action",
                "prepare",
                "-DiscDirectory",
                str(self.downloads),
                "-Discs",
                "1,2",
                "-Stages",
                "s00a,s01a",
            )
        )
        calls = [
            json.loads(line)
            for line in (self.root / "tools/calls.jsonl").read_text().splitlines()
        ]
        self.assertEqual([call["disc"] for call in calls], ["1", "2"])
        self.assertTrue(all(call["stages"] == ["s00a", "s01a"] for call in calls))

    def test_archive_inventory_detects_partial_or_modified_extraction(self):
        self.make_tool(
            "legacy", {"game.exe": b"game", "licenses/notice.txt": b"notice"}
        )
        (self.root / "tools/check-archive.ps1").write_text(
            "param($Archive, $Destination)\n"
            ". (Join-Path $PSScriptRoot 'download-tool.ps1')\n"
            "if (Test-MgsArchiveContents $Archive $Destination) { exit 0 }; exit 1\n"
        )
        destination = self.root / "legacy"
        archive = self.downloads / "legacy.zip"
        arguments = ("-Archive", str(archive), "-Destination", str(destination))
        self.assertNotEqual(
            self.run_script("check-archive.ps1", *arguments).returncode, 0
        )
        with zipfile.ZipFile(archive) as source:
            source.extractall(destination)
        self.assert_success(self.run_script("check-archive.ps1", *arguments))
        (destination / "licenses/notice.txt").write_bytes(b"partial")
        self.assertNotEqual(
            self.run_script("check-archive.ps1", *arguments).returncode, 0
        )

    def test_archive_cannot_escape_staging(self):
        self.make_tool(
            "powershell", {"tool.exe": b"fixture", "../../escaped.txt": b"bad"}
        )
        self.save_lock()
        result = self.run_bootstrap()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("escapes its directory", result.stderr)
        self.assertFalse((self.root / "escaped.txt").exists())
        self.assertFalse((self.root / ".tools/powershell").exists())
