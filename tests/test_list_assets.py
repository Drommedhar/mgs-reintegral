"""Synthetic STAGE.DIR coverage without original game assets."""

import struct
import tempfile
import unittest
from pathlib import Path

from tools.list_assets import Asset, export_asset, list_assets


def stage_fixture() -> bytes:
    blocks = [bytearray(2048) for _ in range(5)]
    struct.pack_into("<I8sI", blocks[0], 0, 12, b"s00a", 1)
    struct.pack_into("<BBH", blocks[1], 0, 1, 0, 4)
    tags = [
        (0, ord("n"), ord("d"), 12),
        (0x5678, ord("c"), ord("g"), 0),
        (0, ord("c"), 0xFF, 4),
        (0x1111, ord("s"), ord("b"), 4),
    ]
    for index, tag in enumerate(tags):
        struct.pack_into("<HBBI", blocks[1], 4 + 8 * index, *tag)
    struct.pack_into("<HHI4s", blocks[2], 0, 0x1234, ord("p"), 4, b"TEX!")
    blocks[3][:4] = b"code"
    blocks[4][:4] = b"mips"
    return b"".join(blocks)


class AssetTests(unittest.TestCase):
    def test_region_boundaries_and_override_flags(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "STAGE.DIR"
            path.write_bytes(stage_fixture())
            resources = list_assets(path, "s00a")
            self.assertEqual(
                [
                    (entry.identity, entry.offset, entry.size, entry.overridable)
                    for entry in resources
                ],
                [
                    ("1234.p", 4104, 4, True),
                    ("5678.g", 6144, 4, True),
                    ("1111.b", 8192, 4, False),
                ],
            )

    def test_export_keeps_source_and_refuses_overwrite(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            path = root / "STAGE.DIR"
            original = stage_fixture()
            path.write_bytes(original)
            resources = list_assets(path, "s00a")
            output = root / "mods/stages/s00a/1234.p"
            receipt = export_asset(path, resources, "1234.p", output)
            self.assertEqual(receipt["size"], 4)
            self.assertEqual(output.read_bytes(), b"TEX!")
            self.assertEqual(path.read_bytes(), original)
            with self.assertRaises(FileExistsError):
                export_asset(path, resources, "1234.p", output)

    def test_rejects_program_and_conflicting_resource_identity(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            path = root / "STAGE.DIR"
            path.write_bytes(stage_fixture())
            resources = list_assets(path, "s00a")
            with self.assertRaisesRegex(ValueError, "not supported"):
                export_asset(path, resources, "1111.b", root / "prog")
            resources.append(Asset("s00a", "1234.p", "c", 6144, 4, True))
            with self.assertRaisesRegex(ValueError, "conflicting"):
                export_asset(path, resources, "1234.p", root / "ambiguous")

    def test_rejects_truncation_and_unknown_stages(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "STAGE.DIR"
            path.write_bytes(stage_fixture())
            with self.assertRaisesRegex(ValueError, "Unknown stage"):
                list_assets(path, "missing")
            path.write_bytes(stage_fixture()[:-2048])
            with self.assertRaisesRegex(ValueError, "exceeds"):
                list_assets(path, "s00a")

    def test_rejects_dar_size_crossing_section(self):
        image = bytearray(stage_fixture())
        struct.pack_into("<I", image, 4096 + 4, 8)
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "STAGE.DIR"
            path.write_bytes(image)
            with self.assertRaisesRegex(ValueError, "DAR resource size"):
                list_assets(path, "s00a")

    def test_rejects_nonincreasing_cache_offsets(self):
        image = bytearray(stage_fixture())
        struct.pack_into("<I", image, 2048 + 4 + 2 * 8 + 4, 0)
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "STAGE.DIR"
            path.write_bytes(image)
            with self.assertRaisesRegex(ValueError, "not increasing"):
                list_assets(path, "s00a")


if __name__ == "__main__":
    unittest.main()
