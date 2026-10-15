"""Prepare original UI artwork locally without embedding it in SDK code."""

import hashlib
import json

from list_assets import list_assets, read_at

from .formats import png
from .ui_codec import codec_art
from .ui_fonts import menu_font
from .ui_formats import rpk4, sight_layout, tim4
from .ui_inventory import inventory_art
from .ui_kcb_font import FONT_ID, kcb_font
from .ui_radar import radar_art

SIGHTS = ("8504.s", "8505.s", "8506.s", "84db.s", "84dc.s", "84dd.s")
FONTS = ("c70e.r", "5d43.r")


def ui_sources(source):
    payloads = {}
    with source.open("rb") as handle:
        for item in list_assets(source, "init"):
            if item.identity not in SIGHTS + FONTS + (FONT_ID, "121f.r"):
                continue
            payload = read_at(handle, item.offset, item.size, source.stat().st_size)
            if item.identity in payloads and payloads[item.identity] != payload:
                raise ValueError("Conflicting original UI source: " + item.identity)
            payloads[item.identity] = payload
    missing = set(SIGHTS + FONTS + (FONT_ID, "121f.r")) - payloads.keys()
    if missing:
        raise ValueError(f"Missing original UI resources: {sorted(missing)}")
    return payloads


def prepare_ui(source, output, disc):
    payloads = ui_sources(source)
    documents = {identity: sight_layout(payloads[identity]) for identity in SIGHTS}
    images = {}
    for identity, large in zip(FONTS, (False, True)):
        width, height, rgba = (
            rpk4(payloads[identity], 45, 44) if large else tim4(payloads[identity])
        )
        texture = identity + ".png"
        images[texture] = png(width, height, rgba)
        documents[identity] = menu_font(large, texture, (width, height))
    texture = FONT_ID + ".png"
    documents[FONT_ID], rgba = kcb_font(payloads[FONT_ID], texture)
    images[texture] = png(*documents[FONT_ID]["size"], rgba)
    documents["radar"], radar_images = radar_art(payloads["5d43.r"])
    images.update(radar_images)
    documents["inventory"], inventory_images = inventory_art(payloads["5d43.r"])
    images.update(inventory_images)
    documents["codec"], codec_images = codec_art(payloads["5d43.r"], payloads["121f.r"])
    images.update(codec_images)
    destination = output / "init/ui"
    destination.mkdir(parents=True, exist_ok=True)
    for filename, image in images.items():
        (destination / filename).write_bytes(image)
    assets = {}
    for identity, document in documents.items():
        path = f"init/ui/{identity}.json"
        (output / path).write_text(
            json.dumps(document, indent=2) + "\n", encoding="utf-8"
        )
        assets[f"mgs/integral-j/disc{disc}/stage/init/{identity}"] = {
            "kind": "ui_layout"
            if identity in SIGHTS
            else "ui_atlas"
            if identity in ("radar", "inventory", "codec")
            else "ui_font",
            "path": path,
            "sha256": hashlib.sha256(
                payloads["5d43.r"] + payloads["121f.r"]
                if identity == "codec"
                else payloads[
                    "5d43.r" if identity in ("radar", "inventory") else identity
                ]
            ).hexdigest(),
        }
    return assets
