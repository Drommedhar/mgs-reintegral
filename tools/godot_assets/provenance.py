"""Exact local source identities and prepared-file dependency revisions."""

import hashlib
import json
from pathlib import Path
from urllib.parse import unquote, urlsplit


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def local_dependency(root: Path, parent: Path, uri: str) -> Path:
    parsed = urlsplit(uri)
    if parsed.scheme or parsed.netloc or parsed.query or parsed.fragment:
        raise ValueError(f"Nonlocal prepared dependency: {uri}")
    path = (parent / unquote(parsed.path)).resolve(strict=True)
    if not path.is_relative_to(root):
        raise ValueError(f"Prepared dependency escapes cache: {uri}")
    return path


def prepared_files(root: Path, asset: dict) -> dict[str, str]:
    path = local_dependency(root, root, asset["path"])
    dependencies = {path}
    if asset["kind"] == "texture":
        dependencies.add(local_dependency(root, path.parent, path.stem + ".stp.png"))
    elif asset["kind"] in ("ui_font", "ui_atlas"):
        document = json.loads(path.read_text(encoding="utf-8"))
        textures = (
            [document["texture"]]
            if asset["kind"] == "ui_font"
            else [entry["texture"] for entry in document["textures"].values()]
        )
        for texture in textures:
            if (
                not isinstance(texture, str)
                or Path(texture).name != texture
                or ":" in texture
                or "\\" in texture
            ):
                raise ValueError("Invalid UI texture dependency")
            dependencies.add(local_dependency(root, path.parent, texture))
    elif asset["kind"] == "ui_layout":
        pass
    elif asset["kind"] == "model":
        document = json.loads(path.read_text(encoding="utf-8"))
        for item in document.get("buffers", []) + document.get("images", []):
            uri = item.get("uri", "")
            if uri and not uri.startswith("data:"):
                dependencies.add(local_dependency(root, path.parent, uri))
    else:
        raise ValueError(f"Unsupported prepared asset kind: {asset['kind']}")
    return {
        file.relative_to(root).as_posix(): digest(file.read_bytes())
        for file in sorted(dependencies)
    }


def stamp_assets(root: Path, assets: dict) -> None:
    root = root.resolve(strict=True)
    records = {}
    for identity, asset in assets.items():
        source = asset["sha256"]
        if len(source) != 64 or any(c not in "0123456789abcdef" for c in source):
            raise ValueError(f"Invalid source digest: {identity}")
        files = prepared_files(root, asset)
        records[identity] = {
            "contentId": "sha256:" + digest((identity + "\n" + source).encode()),
            "preparedFiles": files,
            "preparedRevision": digest(
                json.dumps(
                    files, sort_keys=True, separators=(",", ":"), ensure_ascii=False
                ).encode()
            ),
        }
    for identity, record in records.items():
        assets[identity].update(record)
