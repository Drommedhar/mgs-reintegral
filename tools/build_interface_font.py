"""Reproduce the optional interface coverage atlas without extracted game assets.

Adapted from ImperishableNEET/mgs1-reintegrated f83139e8 (MIT).
Requires Pillow. The supplied Andrew Gleeson font and derived atlas are CC BY-SA
4.0; this script is ordinary repository tooling. Native 8x6 block letterforms
remain square: vector outlines provide clean edges, not invented round corners.
"""

import argparse
import hashlib
import json
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def smooth_outline(points):
    """Replace only monotone alternating single-pixel steps with their chord.

    Long edges, reversals and run endpoints remain unchanged. This leaves
    stems, counters and squared orthogonal corners alone; it is not a general
    contour simplifier or bitmap blur.
    """
    edges = [
        (
            points[(i + 1) % len(points)][0] - p[0],
            points[(i + 1) % len(points)][1] - p[1],
        )
        for i, p in enumerate(points)
    ]
    result = []
    i = 0
    while i < len(points):
        result.append(points[i])
        j, sign_x, sign_y, last_axis = i, 0, 0, -1
        while j < len(points) - 1:
            dx, dy = edges[j]
            axis = 0 if dx else 1
            if (dx and dy) or abs(dx) + abs(dy) != 64 or axis == last_axis:
                break
            if dx and sign_x and (dx > 0) != (sign_x > 0):
                break
            if dy and sign_y and (dy > 0) != (sign_y > 0):
                break
            sign_x, sign_y, last_axis = dx or sign_x, dy or sign_y, axis
            j += 1
        i = j if j - i >= 3 else i + 1
    return result


def smoothed_font(source, destination):
    from array import array

    from fontTools.ttLib import TTFont
    from fontTools.ttLib.tables._g_l_y_f import GlyphCoordinates

    font = TTFont(source)
    assert font["head"].unitsPerEm == 1024
    changed = []
    for character in "NMKZ/XYVW":
        name = font.getBestCmap()[ord(character)]
        glyph = font["glyf"][name]
        coordinates, ends, flags = glyph.getCoordinates(font["glyf"])
        assert all(flag & 1 for flag in flags), (
            "Only straight source contours supported"
        )
        old_bounds = glyph.xMin, glyph.yMin, glyph.xMax, glyph.yMax
        old_metrics = font["hmtx"][name]
        new, new_ends, start = [], [], 0
        for end in ends:
            new.extend(smooth_outline(list(coordinates[start : end + 1])))
            new_ends.append(len(new) - 1)
            start = end + 1
        if len(new) == len(coordinates):
            continue
        glyph.coordinates = GlyphCoordinates(new)
        glyph.endPtsOfContours = new_ends
        glyph.flags = array("B", [1] * len(new))
        glyph.recalcBounds(font["glyf"])
        assert old_bounds == (glyph.xMin, glyph.yMin, glyph.xMax, glyph.yMax)
        assert old_metrics == font["hmtx"][name]
        changed.append(character)
    font.save(destination)
    return changed


def main():
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        type=Path,
        default=root / "renderers/godot/project/interface-font.png",
    )
    parser.add_argument(
        "--smooth",
        action="store_true",
        help="Straighten clear diagonal staircases (requires fontTools).",
    )
    args = parser.parse_args()
    source = root / "assets/fonts/mgs1-codec-gleeson.ttf"
    changed = []
    if args.smooth:
        with tempfile.TemporaryDirectory() as temporary:
            derived = Path(temporary) / "derived.ttf"
            changed = smoothed_font(source, derived)
            # FreeType keeps an open handle on Windows; read into memory so the
            # temporary directory can close without changing the supplied TTF.
            import io

            face = ImageFont.truetype(io.BytesIO(derived.read_bytes()), 128)
    else:
        face = ImageFont.truetype(str(source), 128)
    atlas = Image.new("L", (2048, 672))
    entries = []
    for index, code in enumerate(range(32, 127)):
        cell = Image.new("L", (128, 112))
        # Creator's font renders at 16 px: 2 px top bearing and 8x6 px ink.
        # 128 px font size produces 8 samples per original logical pixel.
        # The recreated digit 1 has a one-pixel extra left bearing relative
        # to Integral's menu sheet. Correct only its position, not its shape.
        ImageDraw.Draw(cell).text(
            (-8 if code == ord("1") else 0, -16), chr(code), font=face, fill=255
        )
        bounds = cell.getbbox()
        if 65 <= code <= 90 or 48 <= code <= 57:
            assert bounds is not None and bounds[2] <= 64 and bounds[3] <= 48, (
                code,
                bounds,
            )
        atlas.paste(cell, ((index % 16) * 128, (index // 16) * 112))
        entries.append({"ascii": code, "ink_bounds": bounds})
    args.output.parent.mkdir(parents=True, exist_ok=True)
    rgba = Image.new("RGBA", atlas.size, (255, 255, 255, 0))
    rgba.putalpha(atlas)
    rgba.save(args.output)
    manifest = {
        "font": "MGS1 Codec recreation by Andrew Gleeson (2025)",
        "source": "https://gleeson.itch.io/mgs1-fonts",
        "license": "CC BY-SA 4.0",
        "license_url": "https://creativecommons.org/licenses/by-sa/4.0/",
        "changes": "ASCII 32..126 rasterized from vector outlines at 8x native coverage; top bearing removed. Original block letterforms retained.",
        "smoothed_diagonals": changed,
        "bearing_adjustments_logical_pixels": {"1": -1},
        "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "atlas_sha256": hashlib.sha256(args.output.read_bytes()).hexdigest(),
        "format": "RGBA PNG; white with alpha coverage; ASCII 32..126; 16 columns; 128x112 cells",
        "logical_ink_box": [8, 6],
        "pillow_version": Image.__version__,
        "entries": entries,
    }
    if changed:
        manifest["changes"] += (
            " Selected monotone single-pixel diagonal staircases replaced by straight edges; endpoints, glyph bounds and font advances preserved."
        )
    args.output.with_suffix(".json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    print(f"{args.output}: 95 glyphs; 2048x672; 8x6 logical block ink")


if __name__ == "__main__":
    main()
