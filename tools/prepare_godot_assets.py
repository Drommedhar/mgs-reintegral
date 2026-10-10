"""Convert verified local Integral disc resources into an ignored Godot asset cache."""

import argparse
import hashlib
import json
from pathlib import Path

from godot_assets.formats import kmd, pcx, png
from godot_assets.gltf import convert_model
from list_assets import list_assets, read_at

PROJECT = Path(__file__).resolve().parents[1]


def stable_id(stage, identity):
    return f"mgs/integral-j/disc1/stage/{stage}/{identity}"


def stage_payloads(stage_dir, stage):
    resources = {}
    with stage_dir.open("rb") as handle:
        for item in list_assets(stage_dir, stage):
            if item.identity[-1] not in "kp":
                continue
            payload = read_at(handle, item.offset, item.size, stage_dir.stat().st_size)
            if item.identity in resources and payload != resources[item.identity]:
                raise ValueError(f"Conflicting resource {stage}/{item.identity}")
            resources[item.identity] = payload
    return resources


def convert_stage(stage_dir, stage, output, shared_textures):
    resources = stage_payloads(stage_dir, stage)
    destination = output / stage
    (destination / "textures").mkdir(parents=True, exist_ok=True)
    assets, textures = {}, dict(shared_textures)
    for identity, payload in sorted(resources.items()):
        if not identity.endswith(".p"):
            continue
        width, height, rgba, mask, metadata = pcx(payload)
        texture_id = identity[:4]
        (destination / "textures" / f"{texture_id}.png").write_bytes(
            png(width, height, rgba)
        )
        (destination / "textures" / f"{texture_id}.stp.png").write_bytes(
            png(width, height, mask)
        )
        textures[texture_id] = {
            "size": [width, height],
            "uri": f"textures/{texture_id}.png",
            **metadata,
        }
        assets[stable_id(stage, identity)] = {
            "kind": "texture",
            "path": f"{stage}/textures/{texture_id}.png",
            "sha256": hashlib.sha256(payload).hexdigest(),
            **textures[texture_id],
        }
    for identity, payload in sorted(resources.items()):
        if not identity.endswith(".k"):
            continue
        count, parts = kmd(payload)
        details = convert_model(
            stable_id(stage, identity),
            count,
            parts,
            textures,
            destination / f"{identity}.gltf",
        )
        assets[stable_id(stage, identity)] = {
            "kind": "model",
            "path": f"{stage}/{identity}.gltf",
            "sha256": hashlib.sha256(payload).hexdigest(),
            **details,
        }
    print(f"{stage}: {len(assets)} converted assets", flush=True)
    return assets, textures


def prepare(content, output, stages):
    content, output = content.resolve(strict=True), output.resolve()
    if not output.is_relative_to(PROJECT / ".local"):
        raise ValueError(
            "Generated retail content must stay inside the project's ignored .local directory"
        )
    receipt = json.loads((content / "manifest.json").read_text(encoding="utf-8"))
    if receipt["serial"] != "SLPM_862.47":
        raise ValueError(
            "Prototype asset preparation supports Integral Japan disc 1 (SLPM_862.47)"
        )
    source = content / "MGS/STAGE.DIR"
    expected = next(
        item["sha256"] for item in receipt["files"] if item["path"] == "MGS/STAGE.DIR"
    )
    if hashlib.sha256(source.read_bytes()).hexdigest() != expected:
        raise ValueError("STAGE.DIR differs from its disc import receipt")
    output.mkdir(parents=True, exist_ok=True)
    assets, common = convert_stage(source, "init", output, {})
    for texture in common.values():
        texture["uri"] = "../init/" + texture["uri"]
    for stage in stages:
        if stage != "init":
            converted, _ = convert_stage(source, stage, output, common)
            assets.update(converted)
    manifest = {
        "schema": 1,
        "edition": "integral-j",
        "disc": 1,
        "sourceImageSha256": receipt["image"]["sha256"],
        "stageDirSha256": expected,
        "coordinates": {"unitsPerMetre": 1000, "axes": ["x", "-y", "-z"]},
        "assets": assets,
    }
    (output / "catalog.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    print(f"Catalog: {output / 'catalog.json'}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--content", type=Path, default=PROJECT / ".local/content/disc1"
    )
    parser.add_argument("--output", type=Path, default=PROJECT / ".local/godot-content")
    parser.add_argument(
        "--stages",
        nargs="+",
        default=[
            "init",
            "init_ve",
            "init_tux",
            "opening",
            "title",
            "abst",
            "s00a",
            "s01a",
            "d00a",
            "d01a",
        ],
    )
    options = parser.parse_args()
    prepare(options.content, options.output, options.stages)
