"""Create a provenance-checked cinematic inventory; original tracks remain local."""

import argparse
import json
from pathlib import Path

from tools.audit_godot_presentation import SERIALS, digest
from tools.godot_assets.cinematics import inspect_file


def inventory(content):
    discs = []
    for disc, serial in SERIALS.items():
        folder = content / f"disc{disc}"
        receipt = json.loads((folder / "manifest.json").read_text(encoding="utf-8"))
        if receipt["serial"] != serial:
            raise ValueError(f"Disc {disc} requires {serial}")
        path = folder / "MGS/DEMO.DAT"
        source_hash = digest(path)
        expected = next(
            item["sha256"]
            for item in receipt["files"]
            if item["path"] == "MGS/DEMO.DAT"
        )
        if source_hash != expected:
            raise ValueError(f"Disc {disc} DEMO.DAT differs from its import receipt")
        discs.append(
            {
                "disc": disc,
                "serial": serial,
                "source_sha256": source_hash,
                "clips": list(inspect_file(path)),
            }
        )
    return {
        "schema": "mgs.presentation.cinematics.v1",
        "discs": discs,
        "limits": "Clip identities, resource names and motion-channel summaries do not prove scenario activation or rendering. No original frame tracks, textures or audio are exported.",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--content",
        type=Path,
        default=Path(__file__).resolve().parents[1] / ".local/content",
    )
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = inventory(args.content)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({disc["serial"]: len(disc["clips"]) for disc in result["discs"]}))


if __name__ == "__main__":
    main()
