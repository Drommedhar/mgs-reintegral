"""Source-backed actor identity, placement and conditional preview coverage."""

import hashlib
import struct
import sys
import unittest
from pathlib import Path
from types import SimpleNamespace

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))

from godot_assets.actor_declarations import actor_declarations, resource_hash
from godot_assets.gltf import part_owners
from language_script import procedures

from tests.test_godot_maps import command, option, script

PREFIX = "mgs/integral-j/disc1/stage/s00a"
ASSETS = {f"{PREFIX}/{model:04x}.k": {} for model in (0x1234, 0x5678)}


def actor(provider, name=0xC056, parameters=b""):
    args = b"\x06" + struct.pack(">H", provider) + b"\x06" + struct.pack(">H", name)
    return command(0x9906, args, parameters)


def vector(name, values):
    data = b"".join(b"\x01" + struct.pack(">h", value) for value in values)
    return bytes([0x50, ord(name), len(data) + 1]) + data


class ActorDeclarations(unittest.TestCase):
    def test_extension_ownership_includes_reachable_parts_only(self):
        parts = [SimpleNamespace(extension=i) for i in (-1, 4, -1, -1, 5, -1, -1)]
        self.assertEqual(part_owners(4, parts), [0, 1, 2, 3, 1, 1, 6])
        parts[5].extension = 1
        with self.assertRaisesRegex(ValueError, "extended KMD"):
            part_owners(4, parts)
        parts[5].extension = 99
        with self.assertRaisesRegex(ValueError, "extended KMD"):
            part_owners(4, parts)

    def test_repeated_options_are_not_guessed(self):
        data = script(actor(0xEC77, parameters=option("m", [0x1234]) * 2))
        record = actor_declarations(data, "s00a", 1, ASSETS)[0]
        self.assertEqual(record["status"], "unresolved")
        self.assertIn("Repeated option", record["reason"])

    def test_duplicate_names_keep_distinct_exact_command_offsets(self):
        first = actor(0xEC77, parameters=option("m", [0x1234]))
        second = actor(0xEC77, parameters=option("m", [0x5678]))
        data = script(first + second)
        records = actor_declarations(data, "s00a", 1, ASSETS)
        self.assertEqual(len(records), 2)
        self.assertEqual(
            [r["target"]["command_offset"] for r in records], [15, 15 + len(first)]
        )
        for record in records:
            self.assertEqual(record["activation"], "startup")
            self.assertEqual(
                record["target"]["script_sha256"], hashlib.sha256(data).hexdigest()
            )
            self.assertEqual(record["name"], 0xC056)
            self.assertEqual(record["status"], "ready")

    def test_nested_equal_command_is_conditional_and_offsets_survive_blocks(self):
        direct = actor(0xEC77, parameters=option("m", [0x1234]))
        nested = b"\x40" + struct.pack(">H", len(direct) + 3) + direct + b"\0"
        data = script(direct + command(0x1234, nested))
        records = actor_declarations(data, "s00a", 1, ASSETS)
        self.assertEqual([r["activation"] for r in records], ["startup", "conditional"])
        for record in records:
            start = record["target"]["command_offset"]
            self.assertEqual(data[start : start + len(direct)], direct)
        nodes = list(procedures(data)[0].walk(0x60))
        self.assertEqual(nodes[0], nodes[-1])

    def test_wall_pose_and_elevator_roles_follow_different_options(self):
        wall = actor(
            0xEC77,
            parameters=option("m", [0x1234])
            + vector("p", [-10, 20, 30])
            + vector("d", [0, 1024, 0]),
        )
        cart = actor(
            0x2ABC,
            parameters=option("m", [0x1234])
            + option("f", [0x5678])
            + vector("s", [1000, 0, -28800]),
        )
        records = actor_declarations(script(wall + cart), "s00a", 1, ASSETS)
        self.assertEqual(records[0]["preview"]["position"], [-10, 20, 30])
        self.assertEqual(records[0]["preview"]["rotation"], [0, 1024, 0])
        self.assertEqual(
            [r["role"] for r in records[1]["models"]], ["body", "secondary"]
        )
        self.assertEqual(records[1]["preview"]["position"], [1000, 0, -28800])

    def test_runtime_values_and_missing_models_are_explicit(self):
        dynamic = actor(0xEC77, parameters=b"\x50m\x05\x16\x80\x00\x0e")
        missing = actor(0xEC77, parameters=option("m", [0x9999]))
        unknown = actor(0xBEEF, parameters=option("m", [0x1234]))
        records = actor_declarations(
            script(dynamic + missing + unknown), "s00a", 1, ASSETS
        )
        self.assertEqual([r["status"] for r in records], ["unresolved", "unprepared"])
        self.assertIn("runtime values", records[0]["reason"])
        self.assertIn("9999.k", records[1]["reason"])
        self.assertNotIn("preview", records[0])

    def test_wall_alias_and_common_model_source_are_resolved(self):
        model = resource_hash("box_01")
        identity = f"mgs/integral-j/disc2/stage/init/{model:04x}.k"
        record = actor_declarations(script(actor(0xEC77)), "s00a", 2, {identity: {}})[0]
        self.assertEqual(record["models"][0]["asset"], identity)
        self.assertEqual(record["preview"]["scale"], [2, 4, 2])
        self.assertEqual(record["preview"]["position"], [0, 200, 0])
        self.assertEqual(resource_hash("cb_box11"), 0xADDB)


if __name__ == "__main__":
    unittest.main()
