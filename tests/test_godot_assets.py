"""Asset bounds, palette semantics and original rig ownership regressions."""

import struct
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from godot_assets.formats import Part, inflate, kmd, pcx
from godot_assets.gltf import face_vertices, point, resolve_vertex
from prepare_godot_assets import stable_id


def pcx_fixture(indices, palette):
    header = bytearray(128)
    struct.pack_into("<4H", header, 4, 0, 0, len(indices) - 1, 0)
    struct.pack_into("<7H", header, 74, 12345, 1, 0, 0, 0, 0, 256)
    return bytes(header) + indices + b"\x0c" + palette


class AssetConversion(unittest.TestCase):
    def test_zero_is_transparent_but_stp_black_is_visible(self):
        palette = bytes([0, 0, 0, 1, 0, 0]) + bytes(762)
        width, height, rgba, mask, _ = pcx(pcx_fixture(bytes([0, 1]), palette))
        self.assertEqual((width, height), (2, 1))
        self.assertEqual(rgba, bytes([0, 0, 0, 0, 0, 0, 0, 255]))
        self.assertEqual(mask[4:], bytes([255, 255, 255, 255]))

    def test_mgs_rle_c0_is_a_literal(self):
        self.assertEqual(inflate(b"\xc0", 0, 1), (b"\xc0", 1))
        with self.assertRaises(ValueError):
            inflate(b"\xc3\x01", 0, 2)
        with self.assertRaises(ValueError):
            inflate(b"\xc1", 0, 1)

    def test_bad_model_extents_are_rejected(self):
        with self.assertRaises(ValueError):
            kmd(struct.pack("<8i", 1, 1, 0, 0, 0, 1, 1, 1))
        with self.assertRaises(ValueError):
            kmd(struct.pack("<8i", 2, 1, 0, 0, 0, 1, 1, 1))

    def test_seam_vertex_uses_parent_bone_and_parent_coordinates(self):
        parent = Part(
            0, -1, (0, 0, 0), -1, [(100, 200, 300, -1)], b"", [], b"", b"", ()
        )
        child = Part(
            0, 0, (10, 20, 30), -1, [(999, 999, 999, 0)], b"", [], b"", b"", ()
        )
        self.assertEqual(resolve_vertex([parent, child], 1, 0), (0, (100, 200, 300)))
        self.assertEqual(point((100, 200, 300)), (0.1, -0.2, -0.3))

    def test_stage_namespace_disambiguates_legacy_hash(self):
        self.assertNotEqual(stable_id("s00a", "1234.k"), stable_id("s01a", "1234.k"))
        self.assertEqual(
            stable_id("s00a", "1234.k"), "mgs/integral-j/disc1/stage/s00a/1234.k"
        )

    def test_uvs_use_last_texel_and_shading_keeps_original_corner_order(self):
        part = Part(
            0,
            -1,
            (0, 0, 0),
            -1,
            [(0, 0, 0, -1)] * 4,
            bytes([0, 1, 2, 3]),
            [(0, -4096, 0, -1)],
            bytes(4),
            bytes([0, 0, 255, 0, 255, 255, 0, 255]),
            (1,),
        )
        vertices = face_vertices([part], 0, 0, [(0, 0, 0)], (32, 32), (0, 1))
        self.assertEqual(vertices[2][1], (31.5 / 32, 0.5 / 32))
        self.assertEqual(
            [round(vertex[4][0] * 256 - 0.5) for vertex in vertices], [0, 3, 1, 1, 3, 2]
        )


if __name__ == "__main__":
    unittest.main()
