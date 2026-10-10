"""Apply a pinned patch stack without confusing later edits with local conflicts."""

import argparse
import json
import os
import subprocess
import tempfile
from pathlib import Path


class PatchRepository:
    def __init__(self, path: Path, index: Path):
        self.path = path.resolve()
        self.environment = os.environ | {"GIT_INDEX_FILE": str(index)}

    def git(self, *arguments: str, data: bytes | None = None) -> bytes:
        result = subprocess.run(
            ["git", "-C", str(self.path), *arguments],
            input=data,
            capture_output=True,
            env=self.environment,
            check=False,
        )
        if result.returncode:
            raise RuntimeError(result.stderr.decode("utf-8", errors="replace").strip())
        return result.stdout

    def trees(self, commit: str, patches: list[Path]) -> tuple[list[str], list[str]]:
        self.git("read-tree", commit)
        trees = [self.git("write-tree").decode().strip()]
        paths = set()
        for patch in patches:
            self.git("apply", "--cached", str(patch.resolve()))
            trees.append(self.git("write-tree").decode().strip())
            changed = self.git("diff", "--name-only", "-z", trees[-2], trees[-1])
            paths.update(name.decode("utf-8") for name in changed.split(b"\0") if name)
        return trees, sorted(paths)

    def tree_files(self, tree: str, paths: list[str]) -> dict[str, str]:
        output = self.git("ls-tree", "-r", "-z", tree, "--", *paths)
        files = {}
        for record in output.split(b"\0"):
            if record:
                metadata, name = record.split(b"\t", 1)
                files[name.decode("utf-8")] = metadata.split()[2].decode()
        return files

    def working_files(self, paths: list[str]) -> dict[str, str]:
        files = {}
        for name in paths:
            path = self.path / name
            if path.is_symlink():
                raise RuntimeError(f"Patch target is a symbolic link: {path}")
            if path.exists():
                if not path.is_file():
                    raise RuntimeError(f"Patch target is not a regular file: {path}")
                files[name] = (
                    self.git(
                        "hash-object", "--path", name, "--stdin", data=path.read_bytes()
                    )
                    .decode()
                    .strip()
                )
        return files


def sync_patch_stack(
    repository: Path, commit: str, patches: list[Path], check: bool
) -> str:
    if not patches:
        return "no patches"
    with tempfile.TemporaryDirectory(prefix="mgs-patch-stack-") as temporary:
        repo = PatchRepository(repository, Path(temporary) / "index")
        trees, paths = repo.trees(commit, patches)
        actual = repo.working_files(paths)
        matching = [
            index
            for index, tree in enumerate(trees)
            if repo.tree_files(tree, paths) == actual
        ]
        if not matching:
            raise RuntimeError(
                "Patch targets do not match any pinned stack prefix; local changes were preserved"
            )
        installed = matching[-1]
        if installed == len(patches):
            return f"all {installed} patches already applied"
        if check:
            raise RuntimeError(
                f"Only {installed} of {len(patches)} source patches are applied"
            )
        delta = repo.git("diff", "--binary", trees[installed], trees[-1])
        repo.git("apply", "--check", "-", data=delta)
        repo.git("apply", "-", data=delta)
        return f"applied {len(patches) - installed} remaining patches"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lock", type=Path, required=True)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    lock = json.loads(args.lock.read_text(encoding="utf-8"))
    project = args.lock.resolve().parent
    repository = next(
        item for item in lock["repositories"] if item["path"] == args.repository
    )
    patches = [project / patch for patch in repository["patches"]]
    try:
        result = sync_patch_stack(
            project / repository["path"], repository["commit"], patches, args.check
        )
    except (OSError, RuntimeError) as error:
        parser.exit(1, f"{repository['path']}: {error}\n")
    print(f"{repository['path']}: {result}")


if __name__ == "__main__":
    main()
