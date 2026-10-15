"""Read bounded Integral DEMO.DAT streams and optionally prepare local camera keys."""

import hashlib
import struct

from .formats import span


def records(packet, offset, count, layout, minimum):
    size = struct.calcsize(layout)
    if count < 0 or count > 4096 or (count and offset < minimum):
        raise ValueError("Invalid DMO array count or offset")
    return list(struct.iter_unpack(layout, span(packet, offset, count * size)))


def header(packet):
    _, start, frames, maps, models, map_offset, model_offset = struct.unpack(
        "<7i", span(packet, 0, 28)
    )
    if start < 0 or frames < 0:
        raise ValueError("Invalid DMO frame range")
    map_rows = records(packet, map_offset, maps, "<2I", 28)
    model_rows = records(packet, model_offset, models, "<5I", 28)
    if len({row[0] for row in model_rows}) != len(model_rows):
        raise ValueError("Ambiguous DMO model track identity")
    return {
        "start_frame": start,
        "declared_frames": frames,
        "maps": [
            {"cache_id": cache, "resource": f"{name:04x}.k"} for cache, name in map_rows
        ],
        "models": [
            {
                "track": track,
                "flags": flags,
                "cache_id": cache,
                "resource": f"{name:04x}.k",
                "name": name_id,
            }
            for track, flags, cache, name, name_id in model_rows
        ],
    }


def frame(packet):
    span(packet, 0, 40)
    number = struct.unpack_from("<i", packet, 4)[0]
    effect_count = max(0, struct.unpack_from("<h", packet, 24)[0])
    effects = records(
        packet, struct.unpack_from("<I", packet, 28)[0], effect_count, "<13i", 40
    )
    count = max(0, struct.unpack_from("<h", packet, 32)[0])
    offset = struct.unpack_from("<I", packet, 36)[0]
    models = records(packet, offset, count, "<I8hI", 40)
    poses = []
    for index, (track, visible, rx, ry, rz, x, y, z, joints, relative) in enumerate(
        models
    ):
        origin = offset + index * 24
        rotations = records(packet, origin + relative, joints, "<3h", origin + 24)
        poses.append((track, bool(visible), (x, y, z, rx, ry, rz), rotations))
    return number, [effect[1] for effect in effects], poses


def observe(state, packet):
    number, effects, poses = frame(packet)
    if state["last_frame"] is not None and number < state["last_frame"]:
        raise ValueError("DMO frame sequence moved backwards")
    state["last_frame"] = number
    state["frame_packets"] += 1
    state["effect_kinds"].update(effects)
    for track, visible, transform, rotations in poses:
        if track not in state["tracks"]:
            raise ValueError(f"DMO pose has no model declaration: {track}")
        motion = state["tracks"][track]
        motion["pose_packets"] += 1
        motion["visible_packets"] += visible
        motion["transform_changes"] += (
            motion["previous"] is not None and motion["previous"] != transform
        )
        motion["previous"] = transform
        motion["nonzero_joint_indices"].update(
            i for i, rotation in enumerate(rotations) if any(rotation)
        )
        motion["joint_counts"].add(len(rotations))


def finish(definition, state, sector, size, digest):
    for model in definition["models"]:
        motion = state["tracks"][model["track"]]
        model["motion"] = {
            key: sorted(value) if isinstance(value, set) else value
            for key, value in motion.items()
            if key != "previous"
        }
    return dict(
        sector=sector,
        stream_bytes=size,
        sha256=digest.hexdigest(),
        **definition,
        frame_packets=state["frame_packets"],
        last_frame=state["last_frame"],
        effect_kinds=sorted(state["effect_kinds"]),
        presentation_acceptance="unverified",
    )


def inspect_stream(stream, total, cameras=None):
    start = stream.tell()
    digest = hashlib.sha256()
    definition = None
    state = {
        "last_frame": None,
        "frame_packets": 0,
        "effect_kinds": set(),
        "tracks": {},
    }
    while stream.tell() < total:
        raw = stream.read(4)
        if len(raw) != 4:
            raise ValueError("Truncated stream packet header")
        digest.update(raw)
        tag = struct.unpack("<I", raw)[0]
        kind, size = tag & 255, tag >> 8
        if kind == 240:
            length = stream.tell() - start
            end = (stream.tell() + 2047) & ~2047
            if end > total or definition is None:
                raise ValueError("Missing DMO header or stream padding")
            stream.seek(end)
            return finish(definition, state, start // 2048, length, digest)
        if (
            kind not in (1, 2, 3, 4, 5, 6, 7, 16)
            or size < 4
            or size % 4
            or size - 4 > total - stream.tell()
        ):
            raise ValueError("Invalid stream packet extent/type")
        data = stream.read(size - 4)
        if len(data) != size - 4:
            raise ValueError("Truncated stream packet")
        digest.update(data)
        if kind != 5:
            continue
        packet = raw + data
        if definition is None:
            definition = header(packet)
            state["tracks"] = {
                model["track"]: {
                    "pose_packets": 0,
                    "visible_packets": 0,
                    "transform_changes": 0,
                    "previous": None,
                    "nonzero_joint_indices": set(),
                    "joint_counts": set(),
                }
                for model in definition["models"]
            }
        else:
            observe(state, packet)
            if cameras is not None:
                camera = struct.unpack_from("<i8h", packet, 4)
                cameras.append(list(camera))
    raise ValueError("Unterminated DMO stream")


def inspect_file(path):
    total = path.stat().st_size
    with path.open("rb") as stream:
        while stream.tell() < total:
            yield inspect_stream(stream, total)
