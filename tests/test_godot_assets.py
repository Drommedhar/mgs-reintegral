"""Asset bounds, palette semantics and original rig ownership regressions."""

import struct
import sys
import tempfile
import json
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from godot_assets.formats import Part, inflate, kmd, pcx
from godot_assets.gltf import convert_model, face_vertices, point, resolve_vertex
from prepare_godot_assets import stable_id
from tests.godot_geometry_fixture import floor_part


def pcx_fixture(indices, palette):
    header = bytearray(128)
    struct.pack_into("<4H", header, 4, 0, 0, len(indices) - 1, 0)
    struct.pack_into("<7H", header, 74, 12345, 1, 0, 0, 0, 0, 256)
    return bytes(header) + indices + b"\x0c" + palette


class AssetConversion(unittest.TestCase):
    def test_null_faces_are_transparent_without_hiding_missing_textures(self):
        part = floor_part()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "fixture.gltf"
            for texture in (0, 0x1234):
                part.textures = (texture,)
                result = convert_model("fixture", 1, [part], {}, path)
                document = json.loads(path.read_text())
                material = document["materials"][0]
                self.assertEqual(result["surfaces"], 1)
                self.assertEqual(result["colorCount"], 4)
                if texture == 0:
                    self.assertEqual(result["unresolvedTextures"], [])
                    self.assertEqual(material["alphaMode"], "MASK")
                    self.assertEqual(
                        material["pbrMetallicRoughness"]["baseColorFactor"][3], 0
                    )
                else:
                    self.assertEqual(result["unresolvedTextures"], ["1234"])

    def test_native_normals_face_outward_in_gltf(self):
        part = floor_part()
        for flags, normal_index in ((0, 0), (0x10000, 0x80)):
            part.flags = flags
            part.normal_indices = bytes([normal_index]) * 4
            vertices = face_vertices([part], 0, 0, [(0, 0, 0)], (2, 2), (0, 1))
            for vertex in vertices:
                self.assertEqual(vertex[-1], (0, -1, 0))
            a, b, c = [vertex[0] for vertex in vertices[:3]]
            ab, ac = [b[i] - a[i] for i in range(3)], [c[i] - a[i] for i in range(3)]
            cross = (
                ab[1] * ac[2] - ab[2] * ac[1],
                ab[2] * ac[0] - ab[0] * ac[2],
                ab[0] * ac[1] - ab[1] * ac[0],
            )
            self.assertGreater(sum(x * n for x, n in zip(cross, vertices[0][-1])), 0)
        part.normals = [(0, 0, 0, 0)]
        self.assertIsNone(
            face_vertices([part], 0, 0, [(0, 0, 0)], (2, 2), (0, 1))[0][-1]
        )

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
        self.assertNotEqual(
            stable_id("s00a", "1234.k", 1), stable_id("s00a", "1234.k", 2)
        )
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
