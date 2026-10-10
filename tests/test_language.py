"""Asset-free localization, stream preservation and native pack validation."""

import os
import struct
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))

from language_assets import regional_text
from language_mapping import Mapping
from language_pack import DEMO, DESCRIPTION, FONT, VOX, add_translation, write_pack
from language_script import Node, Reader, matched_commands
from language_stream import Packet, caption_strings, encode_stream, merge_demo, streams


def caption(text=b"Hello"):
    entry = struct.pack("<4I", 0, 1, 5, 0) + text + b"\0"
    entry = entry.ljust((len(entry) + 3) & ~3, b"\0")
    return struct.pack("<IIHHI", 10, 0, 16, 20, 20 + len(entry)) + bytes(4) + entry


def voice(channel, text=b"Hello", audio=b"ABCD"):
    return [Packet(16, b"\x01\0\0\0"), Packet(channel, caption(text)), Packet(1, audio)]


class LanguageMappingTests(unittest.TestCase):
    def test_german_glyphs_and_controls(self):
        self.assertEqual(
            regional_text(b"f\x1f r\x80#\x80N", "de"), b"f\x80\x9fr\x80#\x80N"
        )
        for data in (b"\x1f", b"\x1f\0", b"\x80"):
            with self.assertRaises(ValueError):
                regional_text(data, "de")

    def test_nested_script_bounds(self):
        for data in (b"\x60\xff\xff", b"\x07\x03A", b"\x60\0\1", b"\xee"):
            with self.assertRaises(ValueError):
                Reader(data).gcl()

    def test_context_matching_preserves_duplicate_command_position(self):
        def procedure(values):
            return Node(
                0x40,
                children=tuple(
                    Node(0x60, b"\xa2\x42", (Node(10, n.to_bytes(4, "big")),))
                    for n in values
                ),
            )

        pairs = list(
            matched_commands({42: procedure([10, 20])}, {42: procedure([90, 100])})
        )
        self.assertEqual(len(pairs), 2)
        self.assertEqual(pairs[1][2].children[0].value, b"\0\0\0d")
        self.assertEqual(
            list(matched_commands({42: procedure([10, 20])}, {42: procedure([90])})), []
        )

    def test_codec_segment_mismatch_is_excluded(self):
        mapping = Mapping("de")
        mapping.codec_streams.add(10)
        mapping.references[VOX][10].add(20)
        banks = {VOX: ({10: voice(6)}, {20: voice(3) + [Packet(3, caption(b"Extra"))]})}
        records = {}
        report = mapping.compile(records, 1, banks)
        self.assertFalse(records)
        self.assertIn("segment count", report["rejected"][0]["reason"])

    def test_ambiguous_stream_mapping_is_excluded(self):
        mapping = Mapping("de")
        mapping.references[VOX][10].update((20, 30))
        records = {}
        mapping.compile(
            records, 1, {VOX: ({10: voice(6)}, {20: voice(3), 30: voice(3)})}
        )
        self.assertFalse(records)

    def test_animation_and_integral_commands_are_preserved(self):
        animation = Packet(5, b"ANIMATION123")
        command = Packet(16, b"\x05\0\0\0")
        base = [command, animation, *voice(6)]
        donor = [Packet(5, b"PAL!"), *voice(3, b"Gr\x1f \x1f(e", b"DE!!")]
        merged = streams(merge_demo(base, donor, "de"))[0]
        self.assertEqual([p for p in merged if p.kind == 5], [animation])
        self.assertIn(command, merged)
        self.assertEqual([p.data for p in merged if p.kind == 1], [b"DE!!"])
        self.assertEqual(caption_strings(merged, 6), [b"Gr\x80\x9f\x80\xa7e"])
        with self.assertRaises(ValueError):
            merge_demo(base, donor + [Packet(1, b"MORE")], "de")

    def test_conflicting_text_is_rejected(self):
        records = {}
        add_translation(records, b"Hello", b"Hallo")
        with self.assertRaises(ValueError):
            add_translation(records, b"Hello", b"Guten Tag")


@unittest.skipUnless(
    os.environ.get("MGS_LANGUAGE_TEST_ENGINE"), "Native engine path required"
)
class NativePackTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="mgs-language-test-")
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name) / "fixture.mgslang"
        font = (
            struct.pack(">II", 392, 0) + struct.pack(">I", 0x04000000) * 96 + bytes(13)
        )
        self.records = {(FONT, 0, 0): font, (DESCRIPTION, 0, 17): b"Card \x1e\0"}
        add_translation(self.records, b"Hello", b"Hallo")

    def inspect(self, expected):
        result = subprocess.run(
            [
                os.environ["MGS_LANGUAGE_TEST_ENGINE"],
                "--check-language",
                str(self.path),
            ],
            capture_output=True,
            timeout=15,
            check=False,
        )
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)

    def test_text_pack_and_overwrite_protection(self):
        write_pack(self.path, 2, self.records)
        self.inspect(0)
        original = self.path.read_bytes()
        with self.assertRaises(FileExistsError):
            write_pack(self.path, 2, self.records)
        self.assertEqual(self.path.read_bytes(), original)

    def test_corrupt_index_payload_and_truncation(self):
        write_pack(self.path, 2, self.records)
        original = self.path.read_bytes()
        for offset in (0, 24, 32, len(original) - 1):
            damaged = bytearray(original)
            damaged[offset] ^= 1
            self.path.write_bytes(damaged)
            self.inspect(2)
        self.path.write_bytes(original[:-1])
        self.inspect(2)

    def test_stream_crc_and_caption_offsets_are_checked(self):
        self.records[VOX, 2, 10] = encode_stream(voice(6))
        write_pack(self.path, 2, self.records)
        self.inspect(0)
        damaged = bytearray(self.path.read_bytes())
        damaged[-1] ^= 1
        self.path.write_bytes(damaged)
        self.inspect(2)
        self.path.unlink()
        bad = bytearray(caption())
        struct.pack_into("<I", bad, 12, 99999)
        self.records[VOX, 2, 10] = encode_stream([Packet(6, bytes(bad))])
        write_pack(self.path, 2, self.records)
        self.inspect(2)


if __name__ == "__main__":
    unittest.main()
