"""Startup map selection and bounded GCX decoding without original assets."""

import struct
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from godot_assets.maps import MAP, MAPDEF, decode_lights, map_lights, map_models


def option(name, values):
    payload = b"".join(b"\x06" + struct.pack(">H", value) for value in values)
    return bytes([0x50, ord(name), len(payload) + 1]) + payload


def command(identity, arguments=b"", parameters=b""):
    body = struct.pack(">H", identity) + bytes([len(arguments) + 1])
    body += arguments + parameters + b"\0"
    return b"\x60" + struct.pack(">H", len(body) + 2) + body


def script(statements):
    body = statements + b"\0"
    block = b"\x40" + struct.pack(">H", len(body) + 2) + body
    return struct.pack(">I", 4) + bytes(4) + struct.pack(">I", len(block)) + block


class MapDefinitions(unittest.TestCase):
    def test_declared_light_tables_preserve_native_values(self):
        table = struct.pack(
            "<IhhhhHHBBBB", 1, -1000, 3000, 5000, 0, 1200, 4000, 80, 180, 130, 0
        )
        data = script(command(MAPDEF, parameters=option("l", [0x1234])))
        records = map_lights(data, {"1234.l": table, "5678.l": table})
        self.assertEqual(
            records,
            [
                {
                    "id": "1234.l/000",
                    "position": [-1000, 3000, 5000],
                    "radius": 1200,
                    "extent": 4000,
                    "color": [80, 180, 130],
                }
            ],
        )
        repeated = script(command(MAP, parameters=option("d", [1, 0x1234, 2, 0x1234])))
        self.assertEqual(map_lights(repeated, {"1234.l": table}), records)

    def test_invalid_or_missing_lights_are_not_silently_ignored(self):
        data = script(command(MAPDEF, parameters=option("l", [0x1234])))
        with self.assertRaisesRegex(ValueError, "missing"):
            map_lights(data, {})
        with self.assertRaises(ValueError):
            decode_lights(struct.pack("<I", 3) + bytes(16), "1234.l")
        with self.assertRaisesRegex(ValueError, "range"):
            decode_lights(struct.pack("<I", 1) + bytes(16), "1234.l")
        self.assertEqual(decode_lights(bytes(4), "empty.l"), [])

    def test_mapdef_selects_only_declared_models(self):
        commands = command(MAPDEF, b"\x06\x01\x23", option("k", [0x1234, 0x5678]))
        commands += command(0x226D, b"\x06\xab\xcd")
        self.assertEqual(map_models(script(commands)), ["1234.k", "5678.k"])

    def test_map_pairs_and_duplicate_declarations(self):
        commands = command(MAP, parameters=option("d", [1, 0x1234, 2, 0x5678]))
        commands += command(MAPDEF, parameters=option("k", [0x1234]))
        commands += command(MAP, parameters=option("a", [3]))
        self.assertEqual(map_models(script(commands)), ["1234.k", "5678.k"])

    def test_invalid_extents_and_nonliteral_models_are_rejected(self):
        data = script(command(MAPDEF, parameters=option("k", [0x1234])))
        for truncated in (data[:3], data[:-1], data[:12] + b"\x40\xff\xff" + data[15:]):
            with self.assertRaises(ValueError):
                map_models(truncated)
        with self.assertRaisesRegex(ValueError, "runtime values"):
            map_models(script(command(MAPDEF, parameters=b"\x50k\x05\x16\x80\x00\x0e")))
        with self.assertRaisesRegex(ValueError, "area/model pairs"):
            map_models(script(command(MAP, parameters=option("d", [1]))))

    def test_model_tokens_inside_other_commands_are_not_map_definitions(self):
        fake = command(MAPDEF, parameters=option("k", [0x1234]))
        self.assertEqual(map_models(script(command(0x226D, parameters=fake))), [])


if __name__ == "__main__":
    unittest.main()
