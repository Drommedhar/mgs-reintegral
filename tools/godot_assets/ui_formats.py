"""Bounded disc readers for static sight vectors and indexed menu artwork."""

import struct

from .formats import span


def indexed4(pixels: bytes, palette: bytes, width: int, height: int) -> bytes:
    if not 0 < width <= 1024 or width % 2 or not 0 < height <= 512:
        raise ValueError("Invalid UI image dimensions")
    if len(pixels) != width * height // 2 or len(palette) != 32:
        raise ValueError("Invalid UI image or palette extent")
    colors = []
    for (value,) in struct.iter_unpack("<H", palette):
        colors.append(
            bytes(
                (
                    (value & 31) * 255 // 31,
                    ((value >> 5) & 31) * 255 // 31,
                    ((value >> 10) & 31) * 255 // 31,
                    255 if value else 0,
                )
            )
        )
    return b"".join(
        colors[index] for pixel in pixels for index in (pixel & 15, pixel >> 4)
    )


def tim4(data: bytes) -> tuple[int, int, bytes]:
    if struct.unpack("<2I", span(data, 0, 8)) != (16, 8):
        raise ValueError("UI font requires a 4-bit TIM with a palette")
    clut_size, _, _, colors, rows = struct.unpack("<I4H", span(data, 8, 12))
    if (clut_size, colors, rows) != (44, 16, 1):
        raise ValueError("UI font requires one 16-color palette")
    palette = bytearray(span(data, 20, 32))
    palette[:2] = b"\0\0"  # menu_number_init explicitly clears palette entry zero.
    offset = 8 + clut_size
    size, _, _, words, height = struct.unpack("<I4H", span(data, offset, 12))
    if size != 12 + words * height * 2 or offset + size != len(data):
        raise ValueError("Invalid TIM image extent")
    width = words * 4
    return (
        width,
        height,
        indexed4(span(data, offset + 12, size - 12), palette, width, height),
    )


def rpk_item(data: bytes, index: int) -> bytes:
    palettes, images, _ = struct.unpack("<BBH", span(data, 0, 4))
    count = palettes + images
    if not 0 <= index < count:
        raise ValueError("RPK item index outside table")
    offsets = struct.unpack(f"<{count}I", span(data, 4, count * 4))
    start = 4 + count * 4
    extent = len(data) - start
    if any(offset % 4 or offset > extent - 4 for offset in offsets):
        raise ValueError("Invalid RPK item offset")
    offset = offsets[index]
    end = min((other for other in offsets if other > offset), default=extent)
    return span(data, start + offset, end - offset)


def rpk4(data: bytes, image_index: int, palette_index: int) -> tuple[int, int, bytes]:
    image = rpk_item(data, image_index)
    palette = rpk_item(data, palette_index)
    _, _, words, height = struct.unpack("<4B", span(image, 0, 4))
    if palette[0] != 16 or len(palette) != 36:
        raise ValueError("UI image requires a 16-color RPK palette")
    size = words * height * 2
    if len(image) != 4 + (size + 3) // 4 * 4:
        raise ValueError("Invalid RPK image extent")
    return (
        words * 4,
        height,
        indexed4(span(image, 4, size), palette[4:], words * 4, height),
    )


def sight_shape(packet: bytes, flags: int) -> dict:
    words, r, g, b, code = struct.unpack("<I4B", span(packet, 0, 8))
    sizes = {0x42: (3, 2), 0x4A: (5, 3), 0x4E: (6, 4), 0x2A: (5, 4)}
    if code not in sizes or words != sizes[code][0] or flags & 63:
        raise ValueError("Unsupported static sight primitive")
    points = list(struct.iter_unpack("<2h", span(packet, 8, sizes[code][1] * 4)))
    if code in (0x4A, 0x4E) and packet[-4:] != b"\x55" * 4:
        raise ValueError("Invalid sight polyline terminator")
    if code == 0x2A:
        points = [points[i] for i in (0, 1, 3, 2)]
    return {
        "type": "polygon" if code == 0x2A else "line",
        "points": points,
        "color": [r, g, b],
        "blend": flags >> 6,
    }


def sight_layout(data: bytes) -> dict:
    size, delay, count, table, buffer, indices, motion, blink = struct.unpack(
        "<HBB5I", span(data, 0, 24)
    )
    if delay or not 0 < count <= 127 or table != 24 or buffer != table + count * 4:
        raise ValueError("Unsupported static sight layout header")
    if buffer + size != len(data) or (indices, motion, blink) != (len(data),) * 3:
        raise ValueError("Animated sight layouts require a separate state adapter")
    primitives = span(data, buffer, size)
    shapes = []
    cursor = 0
    for index in range(count):
        offsets, flags, offset = struct.unpack("<BBH", span(data, table + index * 4, 4))
        if offsets or offset != cursor:
            raise ValueError("Invalid static sight primitive offset")
        words = struct.unpack("<I", span(primitives, offset, 4))[0]
        packet = span(primitives, offset, (words + 1) * 4)
        shapes.append(sight_shape(packet, flags))
        cursor += len(packet)
    if cursor != size:
        raise ValueError("Unreferenced sight primitive bytes")
    return {
        "schema": 1,
        "size": [320, 224],
        "shapes": shapes,
        "draw_order": list(reversed(range(count))),
    }
