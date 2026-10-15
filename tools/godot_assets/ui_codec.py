"""Prepare Codec frame and incoming-call artwork from local original resources."""

from .formats import png
from .ui_formats import rpk4, tim4


def codec_art(menu, call):
    textures, images = {}, {}
    for name, (width, height, rgba) in (
        ("frame", rpk4(menu, 43, 42)),
        ("call", tim4(call)),
    ):
        filename = f"codec-{name}.png"
        textures[name] = {"texture": filename, "size": [width, height]}
        images[filename] = png(width, height, rgba)
    return {"schema": 1, "textures": textures}, images
