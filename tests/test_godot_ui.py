"""Original UI decoding, glyph metrics and source dependency boundaries."""

import json
import struct
import tempfile
import unittest
from pathlib import Path

from tools.godot_assets.provenance import stamp_assets
from tools.godot_assets.ui_codec import codec_art
from tools.godot_assets.ui_fonts import menu_font
from tools.godot_assets.ui_formats import indexed4, rpk4, sight_layout, tim4
from tools.godot_assets.ui_inventory import inventory_art
from tools.godot_assets.ui_radar import radar_art


def sight_fixture(code=0x2A):
    points = ((0, 0), (20, 0), (0, 10), (20, 10))
    packet = struct.pack(
        "<I4B8h", 5, 255, 64, 32, code, *(v for point in points for v in point)
    )
    end = 28 + len(packet)
    return (
        struct.pack("<HBB5IBBH", len(packet), 0, 1, 24, 28, end, end, end, 0, 64, 0)
        + packet
    )


def tim_fixture():
    palette = struct.pack("<16H", 0x7FFF, 0x001F, 0x03E0, *([0] * 13))
    return (
        struct.pack("<2II4H", 16, 8, 44, 0, 0, 16, 1)
        + palette
        + struct.pack("<I4H", 14, 0, 0, 1, 1)
        + b"\x10\x02"
    )


class OriginalUi(unittest.TestCase):
    def test_codec_art_and_truncated_resources(self):
        palette = bytes((16, 0, 0, 0)) + struct.pack("<16H", 0, 0x7FFF, *([0] * 14))
        sprite = bytes((0, 0, 1, 1, 0x11, 0, 0, 0))
        offsets = [0] * 43 + [len(palette)]
        menu = struct.pack("<BBH44I", 1, 43, 0, *offsets) + palette + sprite
        document, images = codec_art(menu, tim_fixture())
        self.assertEqual(set(images), {"codec-frame.png", "codec-call.png"})
        self.assertEqual(document["textures"]["frame"]["size"], [4, 1])
        with self.assertRaises(ValueError):
            codec_art(menu[:-1], tim_fixture())
        with self.assertRaises(ValueError):
            codec_art(menu, tim_fixture()[:-1])

    def test_inventory_icons_offsets_palettes_and_truncation(self):
        palette = bytes((16, 0, 0, 0)) + struct.pack("<16H", 0, 0x7FFF, *([0] * 14))
        sprite = bytes((255, 4, 1, 1, 0x11, 0, 0, 0))
        entries = [
            palette if index in (0, 33, 35, 37, 39, 46, 47) else sprite
            for index in range(49)
        ]
        offsets, size = [], 0
        for entry in entries:
            offsets.append(size)
            size += len(entry)
        data = struct.pack("<BBH49I", 7, 42, 0, *offsets) + b"".join(entries)
        document, images = inventory_art(data)
        self.assertEqual(len(images), 37)
        for index in (1, 22, 27, 34, 36, 38, 40, 48):
            self.assertEqual(document["textures"][str(index)]["size"], [4, 1])
            self.assertEqual(document["textures"][str(index)]["offset"], [-3, 2])
        self.assertEqual(images["inventory-22.png"], images["inventory-27.png"])
        with self.assertRaises(ValueError):
            inventory_art(data[:-1])

    def test_radar_atlas_digits_and_dependencies(self):
        image = bytes((0, 0, 24, 45)) + bytes([0xF1]) * 2160
        data = struct.pack("<BBH42I", 0, 42, 0, *([0] * 42)) + image
        document, images = radar_art(data)
        self.assertEqual(
            set(images), {"radar.png", "radar-alert.png", "radar-evasion.png"}
        )
        self.assertEqual(document["textures"]["art"]["size"], [96, 45])
        self.assertNotEqual(images["radar-alert.png"], images["radar-evasion.png"])
        with self.assertRaises(ValueError):
            radar_art(data[:-1])
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "radar.json").write_text(json.dumps(document))
            for name, pixels in images.items():
                (root / name).write_bytes(pixels)
            assets = {
                "radar": {"kind": "ui_atlas", "path": "radar.json", "sha256": "c" * 64}
            }
            stamp_assets(root, assets)
            self.assertEqual(
                set(assets["radar"]["preparedFiles"]), {"radar.json", *images}
            )
            for invalid in (
                "../outside.png",
                "https://example.com/art.png",
                "missing.png",
            ):
                document["textures"]["art"]["texture"] = invalid
                (root / "radar.json").write_text(json.dumps(document))
                with self.assertRaises((ValueError, FileNotFoundError)):
                    stamp_assets(root, assets)

    def test_quad_winding_blend_and_native_canvas(self):
        layout = sight_layout(sight_fixture())
        self.assertEqual(layout["size"], [320, 224])
        shape = layout["shapes"][0]
        self.assertEqual(shape["points"], [(0, 0), (20, 0), (20, 10), (0, 10)])
        self.assertEqual(shape["blend"], 1)
        self.assertEqual(shape["color"], [255, 64, 32])

    def test_sight_rejects_motion_unknown_packets_and_truncation(self):
        for offset, value in (
            (2, 1),
            (16, 24),
            (24, 1),
            (25, 1),
            (26, 4),
            (28, 255),
            (35, 0xFF),
        ):
            data = bytearray(sight_fixture())
            data[offset] = value
            with self.subTest(offset=offset), self.assertRaises(ValueError):
                sight_layout(bytes(data))
        for length in range(len(sight_fixture())):
            with self.subTest(length=length), self.assertRaises(ValueError):
                sight_layout(sight_fixture()[:length])

    def test_indexed_palette_keeps_opaque_black_but_zero_is_transparent(self):
        palette = struct.pack("<16H", 0, 0x8000, 0x001F, *([0] * 13))
        self.assertEqual(
            indexed4(b"\x10\x02", palette, 4, 1),
            bytes((0, 0, 0, 0, 0, 0, 0, 255, 255, 0, 0, 255, 0, 0, 0, 0)),
        )
        for width, height, pixels in ((3, 1, b"\0\0"), (4, 0, b""), (4, 1, b"\0")):
            with self.assertRaises(ValueError):
                indexed4(pixels, palette, width, height)

    def test_menu_tim_clears_first_color_like_native_loader(self):
        width, height, image = tim4(tim_fixture())
        self.assertEqual((width, height), (4, 1))
        self.assertEqual(image[:4], b"\0\0\0\0")
        self.assertEqual(image[4:12], bytes((255, 0, 0, 255, 0, 255, 0, 255)))
        for length in range(len(tim_fixture())):
            with self.subTest(length=length), self.assertRaises(ValueError):
                tim4(tim_fixture()[:length])

    def test_rpk_offsets_are_relative_to_end_of_table(self):
        palette = bytes((16, 0, 0, 0)) + struct.pack("<16H", 0, 0x7FFF, *([0] * 14))
        image = bytes((0, 0, 1, 1, 0x11, 0, 0, 0))
        data = struct.pack("<BBH2I", 1, 1, 0, 0, len(palette)) + palette + image
        self.assertEqual(rpk4(data, 1, 0), (4, 1, b"\xff" * 8 + b"\0" * 8))
        broken = bytearray(data)
        struct.pack_into("<I", broken, 8, 0xFFFFFFFC)
        with self.assertRaises(ValueError):
            rpk4(bytes(broken), 1, 0)
        for length in range(len(data)):
            with self.subTest(length=length), self.assertRaises(ValueError):
                rpk4(data[:length], 1, 0)

    def test_metrics_preserve_case_folding_narrow_i_and_punctuation(self):
        for large, size in ((False, (256, 10)), (True, (216, 12))):
            font = menu_font(large, "atlas.png", size)
            glyphs = font["glyphs"]
            self.assertEqual(glyphs["73"], glyphs["105"])
            self.assertEqual(glyphs["73"]["advance"], 5 if large else 4)
            self.assertEqual(glyphs["46"]["offset"], 1)
            self.assertEqual(glyphs["46"]["advance"], 4)
            self.assertEqual(glyphs["45"]["advance"], 9 if large else 6)
            self.assertEqual(font["line_height"], 8)
        with self.assertRaises(ValueError):
            menu_font(True, "atlas.png", (1, 1))

    def test_font_and_layout_revisions_include_only_local_dependencies(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "font.json").write_text(json.dumps({"texture": "atlas.png"}))
            (root / "atlas.png").write_bytes(b"pixels")
            (root / "layout.json").write_text(json.dumps(sight_layout(sight_fixture())))
            assets = {
                "font.r": {"kind": "ui_font", "path": "font.json", "sha256": "a" * 64},
                "layout.s": {
                    "kind": "ui_layout",
                    "path": "layout.json",
                    "sha256": "b" * 64,
                },
            }
            stamp_assets(root, assets)
            self.assertEqual(
                set(assets["font.r"]["preparedFiles"]), {"font.json", "atlas.png"}
            )
            self.assertEqual(set(assets["layout.s"]["preparedFiles"]), {"layout.json"})
            before = assets["font.r"]["preparedRevision"]
            (root / "atlas.png").write_bytes(b"new pixels")
            stamp_assets(root, assets)
            self.assertNotEqual(before, assets["font.r"]["preparedRevision"])
            (root / "font.json").write_text('{"texture":"../outside.png"}')
            with self.assertRaises((ValueError, FileNotFoundError)):
                stamp_assets(root, assets)
