"""Exercise overlapping source patches and preservation of local work."""

import subprocess
import tempfile
import unittest
from pathlib import Path

from tools.patch_stack import sync_patch_stack


class PatchStackTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="mgs-patches-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.repo = self.root / "repo"
        self.repo.mkdir()
        self.git("init", "-q")
        self.git("config", "core.autocrlf", "false")
        self.git("config", "user.name", "Patch fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        (self.repo / "game.c").write_bytes(b"int level = 0;\n")
        (self.repo / "notes.txt").write_bytes(b"untouched\n")
        self.git("add", "game.c", "notes.txt")
        self.git("commit", "-qm", "Fixture baseline")
        self.commit = self.git("rev-parse", "HEAD").decode().strip()
        self.patches = []
        for number in (1, 2):
            patch = self.root / f"{number}.patch"
            patch.write_text(
                "diff --git a/game.c b/game.c\n--- a/game.c\n+++ b/game.c\n"
                f"@@ -1 +1 @@\n-int level = {number - 1};\n+int level = {number};\n",
                encoding="utf-8",
                newline="\n",
            )
            self.patches.append(patch)

    def git(self, *arguments):
        return subprocess.run(
            ["git", "-C", str(self.repo), *arguments], capture_output=True, check=True
        ).stdout

    def sync(self, check=False):
        return sync_patch_stack(self.repo, self.commit, self.patches, check)

    def test_fresh_and_repeated_overlapping_stack(self):
        self.assertIn("applied 2", self.sync())
        self.assertEqual((self.repo / "game.c").read_bytes(), b"int level = 2;\n")
        self.assertIn("already applied", self.sync(check=True))
        self.assertIn("already applied", self.sync())

    def test_partial_stack_finishes(self):
        self.git("apply", str(self.patches[0]))
        self.assertIn("applied 1", self.sync())
        self.assertIn("already applied", self.sync(check=True))

    def test_check_does_not_apply_missing_patches(self):
        with self.assertRaisesRegex(RuntimeError, "Only 0 of 2"):
            self.sync(check=True)
        self.assertEqual((self.repo / "game.c").read_bytes(), b"int level = 0;\n")

    def test_conflicting_local_changes_are_preserved(self):
        path = self.repo / "game.c"
        path.write_bytes(b"local work\n")
        with self.assertRaisesRegex(RuntimeError, "local changes were preserved"):
            self.sync()
        self.assertEqual(path.read_bytes(), b"local work\n")

    def test_unrelated_staged_changes_are_preserved(self):
        notes = self.repo / "notes.txt"
        notes.write_bytes(b"my staged notes\n")
        self.git("add", "notes.txt")
        index = (self.repo / ".git/index").read_bytes()
        self.sync()
        self.assertEqual(notes.read_bytes(), b"my staged notes\n")
        self.assertEqual((self.repo / ".git/index").read_bytes(), index)

    def test_added_then_removed_file(self):
        extra = self.root / "extra.patch"
        extra.write_text(
            "diff --git a/extra.txt b/extra.txt\nnew file mode 100644\n"
            "--- /dev/null\n+++ b/extra.txt\n@@ -0,0 +1 @@\n+extra\n",
            encoding="utf-8",
            newline="\n",
        )
        self.patches.append(extra)
        self.sync()
        self.assertEqual((self.repo / "extra.txt").read_bytes(), b"extra\n")
        removal = self.root / "remove.patch"
        removal.write_text(
            "diff --git a/extra.txt b/extra.txt\ndeleted file mode 100644\n"
            "--- a/extra.txt\n+++ /dev/null\n@@ -1 +0,0 @@\n-extra\n",
            encoding="utf-8",
            newline="\n",
        )
        self.patches.append(removal)
        self.sync()
        self.assertFalse((self.repo / "extra.txt").exists())
        self.assertIn("already applied", self.sync(check=True))


if __name__ == "__main__":
    unittest.main()
