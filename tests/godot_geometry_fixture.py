"""Synthetic KMD floor converted through the production glTF exporter."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from godot_assets.formats import Part, png
from godot_assets.gltf import convert_model


def floor_part():
    return Part(
        flags=0,
        parent=-1,
        translation=(0, 0, 0),
        extension=-1,
        vertices=[
            (-4000, 0, -4000, -1),
            (4000, 0, -4000, -1),
            (4000, 0, 4000, -1),
            (-4000, 0, 4000, -1),
        ],
        indices=bytes([0, 1, 2, 3]),
        normals=[(0, -4096, 0, 0)],
        normal_indices=bytes(4),
        uv=bytes([0, 0, 255, 0, 255, 255, 0, 255]),
        textures=(1,),
    )


def write_fixture(directory):
    directory.mkdir(parents=True, exist_ok=True)
    (directory / "albedo.png").write_bytes(png(2, 2, bytes([180, 180, 180, 255]) * 4))
    convert_model(
        "synthetic/floor",
        1,
        [floor_part()],
        {"0001": {"size": [2, 2], "uri": "albedo.png"}},
        directory / "floor.gltf",
    )


if __name__ == "__main__":
    write_fixture(Path(sys.argv[1]))
