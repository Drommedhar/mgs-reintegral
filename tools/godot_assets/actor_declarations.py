"""Prepare visual actor declarations from recovered constructor semantics."""

import hashlib

from language_script import procedures

CHARA = b"\x99\x06"
WALL = 0xEC77
ELEVATOR = 0x2ABC


class Unresolved(ValueError):
    pass


def literal(node):
    if node.code not in (1, 2, 3, 4, 6, 8, 9, 10):
        raise Unresolved("Argument depends on native runtime values")
    return int.from_bytes(node.value, "big", signed=node.code in (1, 9))


def parameter(options, key, default, count=1):
    if key not in options:
        return default
    nodes = options[key]
    if len(nodes) != count:
        raise Unresolved(f"Option -{key} requires {count} literal values")
    values = [literal(node) for node in nodes]
    return values[0] if count == 1 else values


def resource_hash(name):
    value = 0
    for character in name:
        value = (((value << 5) | (value >> 11)) + ord(character)) & 0xFFFF
    return value


def wall(options):
    model = parameter(options, "m", None)
    if model is None:
        model = parameter(options, "t", 0)
    position = parameter(options, "p", [0, 0, 0], 3)
    scale = [1, 1, 1]
    if model in (0, 1, 2):
        alias = ("box_01", "dbx1", "dbx2")[model]
        if model == 0:
            position[1] += 200
            scale = [2, 4, 2]
        model = resource_hash(alias)
    return [("body", model)], {
        "position": position,
        "rotation": parameter(options, "d", [0, 0, 0], 3),
        "scale": scale,
        "pose": "declared",
    }


def elevator(options):
    model = parameter(options, "m", 0)
    if model == 0:
        model = parameter(options, "n", 0)
    if model == 0:
        raise Unresolved("Elevator has no literal primary model")
    models = [("body", model)]
    secondary = parameter(options, "f", 0)
    if secondary:
        models.append(("secondary", secondary))
    start = parameter(options, "s", None, 3)
    if start is None:
        raise Unresolved("Elevator start position is not declared")
    return models, {
        "position": start,
        "rotation": [0, 0, 0],
        "scale": [1, 1, 1],
        "pose": "start endpoint; native state determines active position",
    }


def decode(command, provider, assets, prefix):
    options = {}
    for node in command.children:
        if node.code != 0x50:
            continue
        key = node.value.decode("ascii")
        if key in options:
            raise Unresolved(f"Repeated option -{key} requires native evaluation")
        options[key] = node.children
    models, preview = (wall if provider == WALL else elevator)(options)
    result = []
    for role, model in models:
        if not 0 <= model <= 0xFFFF:
            raise Unresolved("Model resource hash is outside 16 bits")
        candidates = [f"{prefix}/{model:04x}.k"]
        common = prefix.rsplit("/", 1)[0] + "/init"
        candidates.append(f"{common}/{model:04x}.k")
        identity = next((item for item in candidates if item in assets), candidates[0])
        result.append({"role": role, "asset": identity})
    missing = [item["asset"] for item in result if item["asset"] not in assets]
    return {
        "models": result,
        "preview": preview,
        "status": "unprepared" if missing else "ready",
        "reason": "Prepare referenced models: " + ", ".join(missing) if missing else "",
    }


def actor_declarations(data, stage, disc, assets, script=0x6EA54):
    digest = hashlib.sha256(data).hexdigest()
    prefix = f"mgs/integral-j/disc{disc}/stage/{stage}"
    result = []
    for procedure, block in procedures(data).items():
        for command in block.walk(0x60):
            if command.value != CHARA:
                continue
            args = [node for node in command.children if node.code not in (0, 0x50)]
            if not args or args[0].code not in (1, 6, 8):
                continue
            provider = literal(args[0])
            if provider not in (WALL, ELEVATOR):
                continue
            declaration = {
                "target": {
                    "stage": stage,
                    "script": script,
                    "script_sha256": digest,
                    "command_offset": command.offset,
                    "provider": provider,
                },
                "procedure": f"{procedure:04x}",
                "activation": "startup"
                if procedure == 0 and any(command is node for node in block.children)
                else "conditional",
                "models": [],
            }
            try:
                declaration["name"] = literal(args[1]) if len(args) > 1 else 0
                declaration.update(decode(command, provider, assets, prefix))
            except Unresolved as error:
                declaration.update(status="unresolved", reason=str(error))
            result.append(declaration)
    return sorted(result, key=lambda item: item["target"]["command_offset"])
