"""Link literal GCX demo commands to original disc streams without executing scripts."""

import hashlib
import json

from language_script import procedures

from .cinematics import inspect_stream


def script_clips(data):
    references, unresolved = [], []
    for procedure, block in procedures(data).items():
        for ordinal, command in enumerate(block.walk(0x60)):
            if command.value != b"\xa2\x42":
                continue
            origin = {"procedure": f"{procedure:04x}", "command": ordinal}
            option = next(
                (
                    node
                    for node in command.children
                    if node.code == 0x50 and node.value == b"s"
                ),
                None,
            )
            values = option.children if option is not None else ()
            if len(values) != 1 or values[0].code not in (1, 2, 3, 4, 6, 8, 9, 10):
                unresolved.append(
                    {**origin, "reason": "Stream selector depends on runtime values"}
                )
                continue
            value = values[0]
            sector = int.from_bytes(value.value, "big", signed=value.code in (1, 9, 10))
            if sector >= 0:
                references.append({**origin, "sector": sector})
    return references, unresolved


def prepare_clips(content, output, catalog, scripts):
    receipt = json.loads((content / "manifest.json").read_text(encoding="utf-8"))
    source = content / "MGS/DEMO.DAT"
    expected = next(
        item["sha256"] for item in receipt["files"] if item["path"] == "MGS/DEMO.DAT"
    )
    with source.open("rb") as handle:
        actual = hashlib.file_digest(handle, "sha256").hexdigest()
    if actual != expected:
        raise ValueError("DEMO.DAT differs from its disc import receipt")
    references = {}
    for stage, script in scripts.items():
        references[stage], unresolved = script_clips(script)
        catalog["maps"][stage]["unresolved_clips"] = unresolved
    sectors = sorted({ref["sector"] for refs in references.values() for ref in refs})
    clips = {}
    folder = output / "cinematics"
    folder.mkdir(parents=True, exist_ok=True)
    with source.open("rb") as stream:
        for sector in sectors:
            stream.seek(sector * 2048)
            cameras = []
            definition = inspect_stream(stream, source.stat().st_size, cameras)
            identity = f"mgs/integral-j/disc{catalog['disc']}/demo/{sector:08x}"
            relative = f"cinematics/{sector:08x}.json"
            payload = json.dumps(
                {"schema": 1, "id": identity, "camera": cameras}, separators=(",", ":")
            ).encode()
            (output / relative).write_bytes(payload)
            clips[identity] = {
                **definition,
                "path": relative,
                "prepared_sha256": hashlib.sha256(payload).hexdigest(),
            }
    catalog["cinematics"] = clips
    catalog["demoDatSha256"] = expected
    for stage, refs in references.items():
        catalog["maps"][stage]["clips"] = bind_clips(catalog, stage, refs)
    return len(clips)


def bind_clips(catalog, stage, references):
    result = {}
    prefix = f"mgs/integral-j/disc{catalog['disc']}"
    for ref in references:
        identity = f"{prefix}/demo/{ref['sector']:08x}"
        if identity in result:
            result[identity]["declarations"].append(ref)
            continue
        models, missing = [], []
        for model in catalog["cinematics"][identity]["maps"]:
            candidates = [
                f"{prefix}/stage/{source}/{model['resource']}"
                for source in (stage, "init")
            ]
            asset = next(
                (name for name in candidates if name in catalog["assets"]), None
            )
            if asset is None:
                missing.append(model["resource"])
            else:
                models.append(asset)
        result[identity] = {
            "id": identity,
            "models": models,
            "missing_models": missing,
            "declarations": [ref],
        }
    return list(result.values())
