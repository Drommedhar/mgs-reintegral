"""Decode local radar artwork and its palette-driven seven-segment digits."""

import struct

from .formats import png, span
from .ui_formats import indexed4, rpk_item

SEGMENTS = (0x77, 0x24, 0x5D, 0x6D, 0x2E, 0x6B, 0x7B, 0x25, 0x7F, 0x6F)


def radar_art(data):
    item = rpk_item(data, 41)
    if item[:4] != bytes((0, 0, 24, 45)) or len(item) != 2164:
        raise ValueError("Unexpected original radar atlas dimensions")
    pixels = span(item, 4, 2160)
    palette = struct.pack("<16H", *([0] * 15), 0xC210)
    images = {"radar.png": png(96, 45, indexed4(pixels, palette, 96, 45))}
    textures = {"art": {"texture": "radar.png", "size": [96, 45]}}
    digit_pixels = b"".join(pixels[row * 48 : row * 48 + 5] for row in range(26, 42))
    for kind, active in (("alert", 0x8C91), ("evasion", 0x8D11)):
        digits = []
        for mask in SEGMENTS:
            colors = (
                [0]
                + [active if mask & (1 << bit) else 0x8023 for bit in range(7)]
                + [0] * 7
                + [0xC210]
            )
            digits.append(indexed4(digit_pixels, struct.pack("<16H", *colors), 10, 16))
        rgba = b"".join(
            digit[row * 40 : (row + 1) * 40] for row in range(16) for digit in digits
        )
        name = f"radar-{kind}.png"
        images[name] = png(100, 16, rgba)
        textures[kind] = {"texture": name, "size": [100, 16]}
    return {"schema": 1, "textures": textures}, images
