"""Original Japanese message hashes depend on EUC-JP bytes, not UTF-8."""

import tempfile
import unittest
from pathlib import Path

from tools.native_encoding import encode_literals, prepare_sources


class NativeEncodingTests(unittest.TestCase):
    def test_japanese_message_literal_matches_original_bytes(self):
        original = 'GV_StrCode("開く")'
        encoded = encode_literals(original)
        self.assertEqual(encoded, r'GV_StrCode("\263\253\244\257")')
        self.assertNotIn("開く", encoded)

    def test_comments_and_ascii_are_preserved(self):
        original = '// "開く"\n/* "閉じる" */ const char *p = "ASCII\\n";'
        self.assertEqual(encode_literals(original), original)

    def test_quote_escapes_and_adjacent_digits_are_unambiguous(self):
        original = '"\\"開く7\\"" "a"'
        self.assertEqual(encode_literals(original), r'"\"\263\253\244\2577\"" "a"')

    def test_continued_comment_does_not_convert_quoted_text(self):
        original = '// continuation \\\n"開く"\nconst char *p = "開く";'
        encoded = encode_literals(original)
        self.assertTrue(encoded.startswith('// continuation \\\n"開く"\n'))
        self.assertTrue(encoded.endswith(r'"\263\253\244\257";'))

    def test_unsupported_literal_fails_explicitly(self):
        for literal in ('L"開く"', 'u8"開く"', '"😀"'):
            with self.assertRaises((ValueError, UnicodeEncodeError)):
                encode_literals(literal)

    def test_mirror_preserves_headers_originals_and_incremental_timestamps(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source"
            output = root / "generated"
            source.mkdir()
            original = 'const char *message = "開く";\n'
            c_file = source / "actor.c"
            c_file.write_text(original, encoding="utf-8")
            (source / "actor.h").write_text('#define MSG "開く"\n', encoding="utf-8")
            (source / "file.cnf").write_text(
                '#define FILE_NAME "開く"\n', encoding="utf-8"
            )
            mirrored = prepare_sources(source, output, [c_file])
            timestamp = mirrored[0].stat().st_mtime_ns
            prepare_sources(source, output, [c_file])
            self.assertEqual(mirrored[0].stat().st_mtime_ns, timestamp)
            self.assertEqual(c_file.read_text(encoding="utf-8"), original)
            self.assertIn(
                "\\263\\253", (output / "actor.h").read_text(encoding="utf-8")
            )
            self.assertIn(
                "\\263\\253", (output / "file.cnf").read_text(encoding="utf-8")
            )


if __name__ == "__main__":
    unittest.main()
