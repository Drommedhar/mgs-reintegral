"""Check a relocatable release ZIP, its documentation and native build identity."""

import argparse
import hashlib
import json
import posixpath
import re
import subprocess
import tempfile
import zipfile
from pathlib import Path
from urllib.parse import unquote, urlsplit


def check_links(archive, prefix, names):
    missing = []
    for name in names:
        if not name.endswith(".md") or not (
            name.startswith("docs/") or name == "START-HERE.md"
        ):
            continue
        text = archive.read(prefix + name).decode("utf-8-sig")
        text = re.sub(r"```.*?```", "", text, flags=re.DOTALL)
        for target in re.findall(r"\[[^\]]*\]\(([^)]+)\)", text):
            target = target.strip("<>")
            url = urlsplit(target)
            if url.scheme or not url.path:
                continue
            resolved = posixpath.normpath(
                posixpath.join(posixpath.dirname(name), unquote(url.path))
            )
            if resolved not in names:
                missing.append(f"{name} -> {target}")
    if missing:
        raise ValueError(
            "Broken packaged documentation links:\n" + "\n".join(sorted(set(missing)))
        )


def verify(path):
    with zipfile.ZipFile(path) as archive:
        if archive.testzip() is not None:
            raise ValueError("ZIP integrity failure")
        roots = {name.split("/")[0] for name in archive.namelist()}
        if len(roots) != 1:
            raise ValueError("Release ZIP must have one root folder")
        prefix = roots.pop() + "/"
        if prefix != path.name.removesuffix(".zip") + "/":
            raise ValueError(
                "Release archive filename must preserve its versioned root name"
            )
        names = {
            name.removeprefix(prefix)
            for name in archive.namelist()
            if not name.endswith("/")
        }
        if any(
            name.startswith(".tools/")
            or ".." in Path(name).parts
            or Path(name).is_absolute()
            for name in names
        ):
            raise ValueError("Bundled tools or unsafe archive path")
        inventory = json.loads(archive.read(prefix + "package-files.json"))["sha256"]
        if names != set(inventory) | {"package-files.json"}:
            raise ValueError("Release inventory differs from archive")
        for name, expected in inventory.items():
            if hashlib.sha256(archive.read(prefix + name)).hexdigest() != expected:
                raise ValueError("Release hash mismatch: " + name)
        metadata = json.loads(archive.read(prefix + "sdk.json"))
        if ("Editor.cmd" in names) != (metadata["kind"] == "sdk"):
            raise ValueError("Editor entry point does not match package kind")
        check_links(archive, prefix, names)
        with tempfile.TemporaryDirectory(prefix="release probe ü ") as directory:
            native = Path(directory) / "mgs-integral-native.exe"
            native.write_bytes(
                archive.read(prefix + "build/windows-x86-godot/mgs-integral-native.exe")
            )
            version = subprocess.check_output(
                [str(native), "--version"], text=True
            ).strip()
            expected = (
                f"RE:INTEGRAL {metadata['version']} ({metadata['sourceCommit'][:12]})"
            )
            if version != metadata["nativeBuild"] or version != expected:
                raise ValueError("Native executable/version receipt mismatch")
    return {
        "package": path.name,
        "files": len(names),
        "kind": metadata["kind"],
        "version": metadata["version"],
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("packages", nargs="+", type=Path)
    args = parser.parse_args()
    for package in args.packages:
        print(json.dumps(verify(package)))
