"""KCB import bounds, packed pixels, and parity with the actual native font code."""

import os
import struct
import subprocess
import tempfile
import unittest
from pathlib import Path

from tools.godot_assets.ui_kcb_font import DASH_CODE, NATIVE_GLYPH_BASE, kcb_font


def font_fixture():
    descriptors, packed = [], bytearray()
    for index in range(96):
        width = index % 12 + 1
        descriptors.append(((index % 3) << 28) | (width << 24) | len(packed))
        packed.extend(bytes((0x1B, 0xE4, 0x93)) * width)
    header = struct.pack(">2I96I", 392, 392 + len(packed), *descriptors)
    return header + packed + bytes(range(36))


def verify_native(data, native, directory):
    document, image = kcb_font(data, "font.png")
    source, output = directory / "font.res", directory / "font-native.bin"
    source.write_bytes(data)
    subprocess.run([str(native), str(source), str(output)], check=True, timeout=30)
    reference = output.read_bytes()
    palette = []
    for (value,) in struct.iter_unpack("<H", reference[:8]):
        palette.append(
            bytes(((value >> shift & 31) * 255 // 31 for shift in (0, 5, 10)))
            + bytes((255 if value else 0,))
        )
    records = reference[8:]
    if len(records) != len(document["glyphs"]) * 392:
        raise AssertionError("Native reference glyph count differs")
    for start in range(0, len(records), 392):
        code, advance = struct.unpack_from("<2I", records, start)
        glyph = document["glyphs"][str(code)]
        if glyph["advance"] != advance:
            raise AssertionError(f"Native advance differs: {code}")
        x, y, width, height = glyph["rect"]
        for py in range(16):
            for px in range(24):
                rgba = b"\0" * 4
                gy = py - glyph["offset_y"]
                if px < width and 0 <= gy < height:
                    offset = ((y + gy) * document["size"][0] + x + px) * 4
                    rgba = image[offset : offset + 4]
                expected = palette[records[start + 8 + py * 24 + px]]
                if rgba != expected:
                    raise AssertionError(f"Native glyph {code} differs at {px},{py}")
    return len(document["glyphs"])


class KcbFont(unittest.TestCase):
    def test_resource_alignment_after_glyph_bank(self):
        data = font_fixture()
        bank_start = struct.unpack_from(">I", data, 4)[0]
        padded = bytearray(data[:bank_start] + b"\0\0" + data[bank_start:] + b"\0\0")
        struct.pack_into(">I", padded, 4, bank_start + 2)
        self.assertEqual(
            kcb_font(bytes(padded), "font.png"), kcb_font(data, "font.png")
        )
        padded[-1] = 1
        with self.assertRaises(ValueError):
            kcb_font(bytes(padded), "font.png")

    def test_variable_width_rows_are_not_byte_aligned(self):
        document, image = kcb_font(font_fixture(), "font.png")
        glyph = document["glyphs"]["34"]
        self.assertEqual(glyph["advance"], 3)
        self.assertEqual(glyph["offset_y"], 2)
        x, y, width, _ = glyph["rect"]
        rows = []
        for row in range(2):
            offset = ((y + row) * document["size"][0] + x) * 4
            rows.append(list(image[offset : offset + width * 4 : 4]))
        self.assertEqual(rows, [[0, 65, 131], [205, 205, 131]])
        self.assertEqual(document["glyphs"][str(NATIVE_GLYPH_BASE + 1)]["offset_y"], 1)
        self.assertEqual(document["glyphs"][str(DASH_CODE)]["advance"], 18)
        self.assertEqual(document["line_height"], 18)

    def test_rejects_invalid_tables_and_descriptors(self):
        data = font_fixture()
        for offset, value in (
            (0, 388),
            (4, 391),
            (4, len(data) + 1),
            (8, 0),
            (8, 0x31000000),
            (8, 0x0D000000),
            (8, 0x01FFFFFF),
        ):
            modified = bytearray(data)
            struct.pack_into(">I", modified, offset, value)
            with (
                self.subTest(offset=offset, value=value),
                self.assertRaises(ValueError),
            ):
                kcb_font(bytes(modified), "font.png")
        for length in range(len(data)):
            with self.subTest(length=length), self.assertRaises(ValueError):
                kcb_font(data[:length], "font.png")

    @unittest.skipUnless(
        os.environ.get("MGS_KCB_REFERENCE"),
        "Native font reference executable not configured",
    )
    def test_pixels_and_metrics_match_native_font_implementation(self):
        with tempfile.TemporaryDirectory() as directory:
            self.assertEqual(
                verify_native(
                    font_fixture(),
                    Path(os.environ["MGS_KCB_REFERENCE"]),
                    Path(directory),
                ),
                98,
            )
