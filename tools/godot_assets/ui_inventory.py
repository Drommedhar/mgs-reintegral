"""Prepare local inventory sprites from the original menu resource pack."""

import struct

from .formats import png
from .ui_formats import rpk4, rpk_item


def inventory_art(data):
    images, textures = {}, {}
    palettes = {22: 46, 27: 47, 34: 33, 36: 35, 38: 37, 40: 39, 48: 39}
    for index in (*range(1, 33), 34, 36, 38, 40, 48):
        width, height, rgba = rpk4(data, index, palettes.get(index, 0))
        x, y = struct.unpack("<bb", rpk_item(data, index)[:2])
        name = f"inventory-{index}.png"
        images[name] = png(width, height, rgba)
        textures[str(index)] = {
            "texture": name,
            "size": [width, height],
            "offset": [x - 2, y - 2],
        }
    return {"schema": 1, "textures": textures}, images
