"""Synthetic stream validation and motion identity regression cases."""

import hashlib
import io
import json
import struct
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))

from godot_assets.cinematic_scenes import bind_clips, prepare_clips, script_clips

from tests.test_godot_maps import command, script
from tools.godot_assets.cinematics import header, inspect_stream


def packet(data, kind=5):
    return struct.pack("<I", (len(data) + 4) << 8 | kind) + data


def clip_header():
    return packet(struct.pack("<6i5I", 0, 2, 0, 1, 28, 28, 7, 0, 0xA1234, 0x1234, 0))


def pose(number, x, rotation=0, track=7):
    data = bytearray(68)
    struct.pack_into("<i", data, 0, number)
    struct.pack_into("<h2xI", data, 28, 1, 40)
    struct.pack_into(
        "<I8hI3h", data, 36, track, 1, 0, 0, 0, x, 0, 0, 1, 24, rotation, 0, 0
    )
    return packet(data)


def stream(*packets):
    data = b"".join(packets) + b"\xf0\0\0\0"
    return data.ljust((len(data) + 2047) & ~2047, b"\0")


class CinematicInventoryTests(unittest.TestCase):
    def inspect(self, data):
        return inspect_stream(io.BytesIO(data), len(data))

    def test_tracks_keep_identity_and_do_not_export_original_animation(self):
        result = self.inspect(stream(clip_header(), pose(1, 0), pose(2, 500, 256)))
        model = result["models"][0]
        self.assertEqual((model["track"], model["resource"]), (7, "1234.k"))
        self.assertEqual(model["motion"]["nonzero_joint_indices"], [0])
        self.assertEqual(model["motion"]["transform_changes"], 1)
        self.assertEqual(model["motion"]["visible_packets"], 2)
        self.assertNotIn("previous", model["motion"])
        self.assertNotIn("frames", result)
        self.assertEqual(result["presentation_acceptance"], "unverified")

    def test_relative_joint_pointer_is_checked_within_its_packet(self):
        data = bytearray(pose(1, 0))
        struct.pack_into("<I", data, 60, 0xFFFFFFF0)
        with self.assertRaises(ValueError):
            self.inspect(stream(clip_header(), data))

    def test_undeclared_track_and_reversed_time_are_rejected(self):
        for packets in [(pose(1, 0, track=8),), (pose(2, 0), pose(1, 0))]:
            with self.subTest(packets=packets), self.assertRaises(ValueError):
                self.inspect(stream(clip_header(), *packets))

    def test_malformed_header_counts_and_stream_extents_are_rejected(self):
        bad = bytearray(clip_header())
        struct.pack_into("<i", bad, 16, 4097)
        with self.assertRaises(ValueError):
            header(bad)
        for data in [
            b"\x05",
            clip_header(),
            struct.pack("<I", 4096 << 8 | 5),
            stream(),
        ]:
            with self.subTest(data=data), self.assertRaises(ValueError):
                self.inspect(data)

    def test_static_selectors_include_nested_branches_and_sector_zero(self):
        demo = command(0xA242, parameters=b"\x50s\x06\x0a\x00\x00\x00\x00")
        nested = command(0x0D86, arguments=script(demo)[12:])
        placeholder = command(0xA242, parameters=b"\x50s\x06\x0a\xff\xff\xff\xff")
        dynamic = command(0xA242, parameters=b"\x50s\x05\x16\x80\x00\x0e")
        refs, unresolved = script_clips(script(nested + placeholder + dynamic))
        self.assertEqual([ref["sector"] for ref in refs], [0])
        self.assertEqual(refs[0]["procedure"], "0000")
        self.assertEqual(len(unresolved), 1)
        self.assertIn("runtime", unresolved[0]["reason"])

    def test_clip_binding_requires_exact_stage_or_resident_model(self):
        prefix = "mgs/integral-j/disc2"
        identity = prefix + "/demo/00000000"
        catalog = {
            "disc": 2,
            "assets": {prefix + "/stage/init/1234.k": {}},
            "cinematics": {
                identity: {"maps": [{"resource": "1234.k"}, {"resource": "5678.k"}]}
            },
        }
        result = bind_clips(catalog, "opening", [{"sector": 0}, {"sector": 0}])
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]["models"], [prefix + "/stage/init/1234.k"])
        self.assertEqual(result[0]["missing_models"], ["5678.k"])
        self.assertEqual(len(result[0]["declarations"]), 2)

    def test_local_camera_preparation_preserves_keys_and_checks_receipt(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "MGS").mkdir()
            frame = bytearray(pose(1, 0))
            struct.pack_into("<8h", frame, 8, 100, 200, 300, 400, 500, 600, 256, 320)
            payload = stream(clip_header(), frame)
            (root / "MGS/DEMO.DAT").write_bytes(payload)
            receipt = {
                "files": [
                    {
                        "path": "MGS/DEMO.DAT",
                        "sha256": hashlib.sha256(payload).hexdigest(),
                    }
                ]
            }
            (root / "manifest.json").write_text(json.dumps(receipt))
            catalog = {"disc": 1, "assets": {}, "maps": {"opening": {}}}
            scripts = {
                "opening": script(command(0xA242, parameters=b"\x50s\x06\x0a\0\0\0\0"))
            }
            self.assertEqual(prepare_clips(root, root, catalog, scripts), 1)
            identity, definition = next(iter(catalog["cinematics"].items()))
            camera_file = root / definition["path"]
            camera = json.loads(camera_file.read_bytes())
            self.assertEqual(camera["id"], identity)
            self.assertEqual(
                camera["camera"], [[1, 100, 200, 300, 400, 500, 600, 256, 320]]
            )
            self.assertEqual(
                hashlib.sha256(camera_file.read_bytes()).hexdigest(),
                definition["prepared_sha256"],
            )
            (root / "MGS/DEMO.DAT").write_bytes(payload + b"changed")
            with self.assertRaisesRegex(ValueError, "receipt"):
                prepare_clips(root, root, catalog, scripts)


if __name__ == "__main__":
    unittest.main()
