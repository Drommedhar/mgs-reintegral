"""Convert verified local Integral disc resources into an ignored Godot asset cache."""

import argparse
import hashlib
import json
from pathlib import Path

from godot_assets.actor_declarations import actor_declarations
from godot_assets.cinematic_scenes import prepare_clips
from godot_assets.formats import kmd, pcx, png
from godot_assets.gltf import convert_model, part_owners
from godot_assets.maps import map_lights, map_models
from godot_assets.provenance import stamp_assets
from godot_assets.ui_assets import prepare_ui
from list_assets import list_assets, read_at, stage_table

PROJECT = Path(__file__).resolve().parents[1]
DISC_SERIALS = {"SLPM_862.47": 1, "SLPM_862.48": 2}


def stable_id(stage, identity, disc=1):
    return f"mgs/integral-j/disc{disc}/stage/{stage}/{identity}"


def campaign_stages(source):
    configured = json.loads((PROJECT / "config/stages.json").read_text())["stages"]
    with source.open("rb") as handle:
        available = stage_table(handle, source.stat().st_size)
    requested = set(configured) | {"init", "init_ve", "init_tux"}
    missing = requested - available.keys()
    if missing:
        raise ValueError(f"Configured stages missing from disc: {sorted(missing)}")
    return sorted(requested)


def stage_payloads(stage_dir, stage):
    resources = {}
    with stage_dir.open("rb") as handle:
        for item in list_assets(stage_dir, stage):
            if item.identity[-1] not in "kpgl":
                continue
            payload = read_at(handle, item.offset, item.size, stage_dir.stat().st_size)
            if item.identity in resources and payload != resources[item.identity]:
                raise ValueError(f"Conflicting resource {stage}/{item.identity}")
            resources[item.identity] = payload
    return resources


def convert_stage(stage_dir, stage, output, shared_textures, disc=1):
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
        assets[stable_id(stage, identity, disc)] = {
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
            stable_id(stage, identity, disc),
            count,
            parts,
            textures,
            destination / f"{identity}.gltf",
        )
        assets[stable_id(stage, identity, disc)] = {
            "kind": "model",
            "path": f"{stage}/{identity}.gltf",
            "sha256": hashlib.sha256(payload).hexdigest(),
            **details,
        }
    print(f"{stage}: {len(assets)} converted assets", flush=True)
    script = resources.get("ea54.g")
    models = map_models(script) if script is not None else []
    for identity in models:
        if stable_id(stage, identity, disc) not in assets:
            raise ValueError(
                f"Map declaration references missing model {stage}/{identity}"
            )
    layout = {
        "models": [stable_id(stage, identity, disc) for identity in models],
        "lights": map_lights(script, resources) if script is not None else [],
        "scope": "startup-map-definitions",
        "script_sha256": hashlib.sha256(script).hexdigest() if script else "",
    }
    return assets, textures, layout


def prepare(
    content,
    output=None,
    stages=None,
    cinematics_only=False,
    ui_only=False,
    declarations_only=False,
):
    if sum((cinematics_only, ui_only, declarations_only)) > 1:
        raise ValueError("Choose one incremental preparation mode")
    content = content.resolve(strict=True)
    receipt = json.loads((content / "manifest.json").read_text(encoding="utf-8"))
    if receipt["serial"] not in DISC_SERIALS:
        raise ValueError(
            "Asset preparation requires Integral Japan campaign disc 1 or 2"
        )
    disc = DISC_SERIALS[receipt["serial"]]
    cache_name = "godot-content" if disc == 1 else "godot-content-disc2"
    output = (output or PROJECT / ".local" / cache_name).resolve()
    if not output.is_relative_to(PROJECT / ".local"):
        raise ValueError(
            "Generated retail content must stay inside the project's ignored .local directory"
        )
    source = content / "MGS/STAGE.DIR"
    expected = next(
        item["sha256"] for item in receipt["files"] if item["path"] == "MGS/STAGE.DIR"
    )
    if hashlib.sha256(source.read_bytes()).hexdigest() != expected:
        raise ValueError("STAGE.DIR differs from its disc import receipt")
    output.mkdir(parents=True, exist_ok=True)
    if cinematics_only or ui_only or declarations_only:
        manifest = json.loads((output / "catalog.json").read_text(encoding="utf-8"))
        if manifest.get("disc") != disc or manifest.get("stageDirSha256") != expected:
            raise ValueError(
                "Prepare matching map assets before incremental preparation"
            )
        if declarations_only:
            stages = list(manifest["maps"]) if stages is None else stages
            for stage in stages:
                if stage not in manifest["maps"]:
                    raise ValueError(f"Prepare map assets before declarations: {stage}")
                resources = stage_payloads(source, stage)
                for identity, payload in resources.items():
                    asset = manifest["assets"].get(stable_id(stage, identity, disc))
                    if asset is not None and identity.endswith(".k"):
                        count, parts = kmd(payload)
                        asset["partOwners"] = part_owners(count, parts)
                script = resources.get("ea54.g")
                manifest["maps"][stage]["actors"] = (
                    actor_declarations(script, stage, disc, manifest["assets"])
                    if script
                    else []
                )
            pending = output / "catalog.json.pending"
            pending.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
            pending.replace(output / "catalog.json")
            print(f"Prepared actor declarations for {len(stages)} maps: {output}")
        elif ui_only:
            assets = prepare_ui(source, output, disc)
            stamp_assets(output, assets)
            manifest["assets"].update(assets)
            (output / "catalog.json").write_text(
                json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
            )
            print(f"Prepared {len(assets)} original UI assets: {output}")
        else:
            prepare_scene_clips(content, source, output, manifest)
        return
    stages = campaign_stages(source) if stages is None else stages
    assets, common, _ = convert_stage(source, "init", output, {}, disc)
    maps = {}
    for texture in common.values():
        texture["uri"] = "../init/" + texture["uri"]
    for stage in stages:
        if stage != "init":
            converted, _, layout = convert_stage(source, stage, output, common, disc)
            assets.update(converted)
            maps[stage] = layout
    assets.update(prepare_ui(source, output, disc))
    stamp_assets(output, assets)
    manifest = {
        "schema": 1,
        "edition": "integral-j",
        "disc": disc,
        "sourceImageSha256": receipt["image"]["sha256"],
        "stageDirSha256": expected,
        "coordinates": {"unitsPerMetre": 1000, "axes": ["x", "-y", "-z"]},
        "assets": assets,
        "maps": maps,
    }
    prepare_scene_clips(content, source, output, manifest)


def prepare_scene_clips(content, source, output, manifest):
    scripts = {}
    for stage in manifest["maps"]:
        script = stage_payloads(source, stage).get("ea54.g")
        if script is not None:
            scripts[stage] = script
            manifest["maps"][stage]["actors"] = actor_declarations(
                script, stage, manifest["disc"], manifest["assets"]
            )
    count = prepare_clips(content, output, manifest, scripts)
    (output / "catalog.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    print(f"Catalog: {output / 'catalog.json'} ({count} cinematic clips)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--content", type=Path, default=PROJECT / ".local/content/disc1"
    )
    parser.add_argument("--output", type=Path)
    incremental = parser.add_mutually_exclusive_group()
    incremental.add_argument(
        "--declarations-only",
        action="store_true",
        help="Refresh actor declarations without reconverting prepared models",
    )
    incremental.add_argument(
        "--cinematics-only",
        action="store_true",
        help="Add local clip previews to an existing matching map cache",
    )
    incremental.add_argument(
        "--ui-only",
        action="store_true",
        help="Add original UI resources to an existing matching map cache",
    )
    parser.add_argument(
        "--stages",
        nargs="+",
        help="Limit preparation to these stages; defaults to the configured campaign",
    )
    options = parser.parse_args()
    prepare(
        options.content,
        options.output,
        options.stages,
        options.cinematics_only,
        options.ui_only,
        options.declarations_only,
    )
