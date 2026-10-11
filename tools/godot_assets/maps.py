"""Read startup map declarations using the recovered libgcl and game/map.c layouts."""

import struct

from godot_assets.formats import span

MAP = 0xC091
MAPDEF = 0x7D50


def unsigned_short(data, offset):
    return struct.unpack(">H", span(data, offset, 2))[0]


def commands(data):
    main = struct.unpack(">I", span(data, 0, 4))[0] + 8
    length = struct.unpack(">I", span(data, main - 4, 4))[0]
    block = span(data, main, length)
    if len(block) < 4 or block[0] != 0x40 or unsigned_short(block, 1) + 1 != length:
        raise ValueError("Invalid GCX main block")
    cursor = 3
    while cursor < length:
        tag = block[cursor]
        if tag == 0:
            if cursor != length - 1:
                raise ValueError("Trailing GCX main statements")
            return
        if tag == 0x60:
            size = unsigned_short(block, cursor + 1) + 1
            command = span(block, cursor, size)
            if size < 7:
                raise ValueError("Truncated GCX command")
            yield command
        elif tag in (0x30, 0x70):
            size = span(block, cursor + 1, 1)[0] + 1
            if size < 2:
                raise ValueError("Invalid GCX statement size")
            span(block, cursor, size)
        else:
            raise ValueError(f"Unsupported GCX statement {tag:#x}")
        cursor += size
    raise ValueError("GCX main block has no terminator")


def options(command):
    cursor = 5 + command[5]
    if cursor < 6 or cursor >= len(command):
        raise ValueError("Invalid GCX option offset")
    result = {}
    while command[cursor] != 0:
        tag, name, length = span(command, cursor, 3)
        if tag != 0x50 or length < 1 or name in result:
            raise ValueError("Invalid GCX map option")
        result[name] = span(command, cursor + 3, length - 1)
        cursor += length + 2
        span(command, cursor, 1)
    return result


def constants(data):
    values, cursor = [], 0
    formats = {1: ">h", 2: ">B", 3: ">B", 4: ">B", 6: ">H", 8: ">H", 9: ">i", 10: ">I"}
    while cursor < len(data):
        tag = data[cursor]
        if tag not in formats:
            raise ValueError("Map declaration depends on runtime values")
        fmt = formats[tag]
        size = struct.calcsize(fmt)
        values.append(struct.unpack(fmt, span(data, cursor + 1, size))[0])
        cursor += size + 1
    return values


def map_models(data):
    models = []
    for command in commands(data):
        identity = unsigned_short(command, 3)
        if identity not in (MAP, MAPDEF):
            continue
        parameters = options(command)
        if identity == MAPDEF:
            names = constants(parameters.get(ord("k"), b""))
        elif ord("d") in parameters:
            pairs = constants(parameters[ord("d")])
            if len(pairs) % 2:
                raise ValueError("Map -d requires area/model pairs")
            names = pairs[1::2]
        else:
            continue
        for name in names:
            if not 0 <= name <= 0xFFFF:
                raise ValueError("Map model hash is outside 16 bits")
            resource = f"{name:04x}.k"
            if resource not in models:
                models.append(resource)
    return models


def map_lights(data, resources):
    """Resolve GM_CreateMap/GM_SetMap light tables, excluding unrelated .l files."""
    names = []
    for command in commands(data):
        identity = unsigned_short(command, 3)
        if identity not in (MAP, MAPDEF):
            continue
        parameters = options(command)
        if identity == MAPDEF:
            selected = constants(parameters.get(ord("l"), b""))
            if len(selected) > 1:
                raise ValueError("Mapdef -l requires one light table")
        else:
            pairs = constants(parameters.get(ord("d"), b""))
            if len(pairs) % 2:
                raise ValueError("Map -d requires area/model pairs")
            selected = pairs[1::2]
        for name in selected:
            resource = f"{name:04x}.l"
            if resource not in resources:
                if identity == MAPDEF:
                    raise ValueError(f"Map light table is missing: {resource}")
                continue  # GM_SetMap permits a missing optional light table.
            if resource not in names:
                names.append(resource)
    lights = []
    for name in names:
        lights.extend(decode_lights(resources[name], name))
    return lights


def decode_lights(data, resource):
    count = struct.unpack("<I", span(data, 0, 4))[0]
    records = span(data, 4, count * 16)
    lights = []
    for index in range(count):
        x, y, z, _, radius, extent, r, g, b, _ = struct.unpack_from(
            "<hhhhHHBBBB", records, index * 16
        )
        if radius == 0 or extent == 0:
            raise ValueError(f"Invalid light range in {resource}, light {index}")
        lights.append(
            {
                "id": f"{resource}/{index:03d}",
                "position": [x, y, z],
                "radius": radius,
                "extent": extent,
                "color": [r, g, b],
            }
        )
    return lights
