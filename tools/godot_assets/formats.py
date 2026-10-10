"""Bounded readers for the original KMD and MGS PCX loaders' input formats."""

import struct
import zlib
from dataclasses import dataclass


def span(data: bytes, offset: int, size: int) -> bytes:
    if offset < 0 or size < 0 or offset + size > len(data):
        raise ValueError("Asset field extends outside its resource")
    return data[offset : offset + size]


@dataclass
class Part:
    flags: int
    parent: int
    translation: tuple
    extension: int
    vertices: list
    indices: bytes
    normals: list
    normal_indices: bytes
    uv: bytes
    textures: tuple


def kmd(data: bytes) -> tuple[int, list[Part]]:
    count, extended = struct.unpack_from("<2i", span(data, 0, 32))
    if not 0 < count <= extended <= 256:
        raise ValueError("Invalid KMD part count")
    parts = []
    for index in range(extended):
        fields = struct.unpack("<22i", span(data, 32 + index * 88, 88))
        flags, faces = fields[:2]
        parent, extension, vertices, vertex_offset, index_offset = fields[11:16]
        normals, normal_offset, ni_offset, uv_offset, texture_offset = fields[16:21]
        if (
            not 0 <= vertices <= 256
            or not 0 <= normals <= 256
            or not 0 <= faces <= 65535
        ):
            raise ValueError("Invalid KMD geometry counts")
        if parent < -1 or parent >= index:
            raise ValueError("KMD parent is not an earlier part")
        parts.append(
            Part(
                flags,
                parent,
                tuple(fields[8:11]),
                extension,
                list(
                    struct.iter_unpack("<4h", span(data, vertex_offset, vertices * 8))
                ),
                span(data, index_offset, faces * 4),
                list(struct.iter_unpack("<4h", span(data, normal_offset, normals * 8))),
                span(data, ni_offset, faces * 4),
                span(data, uv_offset, faces * 8),
                struct.unpack(f"<{faces}H", span(data, texture_offset, faces * 2)),
            )
        )
    return count, parts


def inflate(data: bytes, cursor: int, size: int) -> tuple[bytes, int]:
    output = bytearray()
    while len(output) < size:
        value = span(data, cursor, 1)[0]
        cursor += 1
        count = 1
        if value > 0xC0:
            count = value - 0xC0
            value = span(data, cursor, 1)[0]
            cursor += 1
        if count > size - len(output):
            raise ValueError("PCX run exceeds scanline/image")
        output.extend(bytes([value]) * count)
    return bytes(output), cursor


def pcx_indices(data: bytes, width: int, height: int, flag: int) -> tuple[bytes, bytes]:
    if flag & 1:
        indices, cursor = inflate(data, 128, width * height)
        if span(data, cursor, 1) != b"\x0c":
            raise ValueError("Missing 8-bit PCX palette marker")
        return indices, span(data, cursor + 1, 768)
    stride = struct.unpack_from("<H", data, 66)[0]
    if stride * 8 < width or stride > 4096:
        raise ValueError("Invalid planar PCX stride")
    indices = bytearray()
    cursor = 128
    for _ in range(height):
        row, cursor = inflate(data, cursor, stride * 4)
        for x in range(width):
            indices.append(
                sum(
                    ((row[plane * stride + x // 8] >> (7 - x % 8)) & 1) << plane
                    for plane in range(4)
                )
            )
    return bytes(indices), data[16:64]


def pcx(data: bytes) -> tuple[int, int, bytes, bytes, dict]:
    span(data, 0, 128)
    x0, y0, x1, y1 = struct.unpack_from("<4H", data, 4)
    stamp, flag, px, py, cx, cy, colors = struct.unpack_from("<7H", data, 74)
    width, height = x1 - x0 + 1, y1 - y0 + 1
    if stamp != 12345 or not 0 < width <= 4096 or not 0 < height <= 4096:
        raise ValueError("Invalid MGS PCX header")
    indices, palette = pcx_indices(data, width, height, flag)
    if colors < 1 or colors * 3 > len(palette):
        raise ValueError("Invalid PCX palette size")
    rgba, mask = bytearray(), bytearray()
    for index in indices:
        if index >= colors:
            raise ValueError("PCX pixel references missing palette entry")
        r, g, b = palette[index * 3 : index * 3 + 3]
        stp = 255 if (r | g | b) & 7 else 0
        alpha = 255 if (r | g | b) else 0
        rgba.extend(
            ((r >> 3) * 255 // 31, (g >> 3) * 255 // 31, (b >> 3) * 255 // 31, alpha)
        )
        mask.extend((stp, stp, stp, 255))
    return (
        width,
        height,
        bytes(rgba),
        bytes(mask),
        {
            "flags": flag,
            "abr": (flag >> 4) & 3,
            "depth": 8 if flag & 1 else 4,
            "imageOrigin": [px, py],
            "clutOrigin": [cx, cy],
            "paletteEntries": colors,
        },
    )


def png(width: int, height: int, rgba: bytes) -> bytes:
    if len(rgba) != width * height * 4:
        raise ValueError("RGBA image extent mismatch")

    def chunk(kind, payload):
        return (
            struct.pack(">I", len(payload))
            + kind
            + payload
            + struct.pack(">I", zlib.crc32(kind + payload))
        )

    rows = b"".join(
        b"\0" + rgba[y * width * 4 : (y + 1) * width * 4] for y in range(height)
    )
    header = struct.pack(">2I5B", width, height, 8, 6, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(rows))
        + chunk(b"IEND", b"")
    )
