"""Asset-free fixtures for disc identity, malformed ISO input and safe extraction."""

import hashlib
import io
import json
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch

from tools import import_content as importer


def both(value: int, width: int) -> bytes:
    return value.to_bytes(width, "little") + value.to_bytes(width, "big")


def record(name: bytes, lba: int, size: int, directory: bool = False) -> bytes:
    length = 33 + len(name) + (not len(name) % 2)
    result = bytearray(length)
    result[0] = length
    result[2:10] = both(lba, 4)
    result[10:18] = both(size, 4)
    result[25] = 2 if directory else 0
    result[28:32] = both(1, 2)
    result[32] = len(name)
    result[33 : 33 + len(name)] = name
    return bytes(result)


def raw_sector(payload: bytes, form2: bool = False) -> bytes:
    result = bytearray(importer.SECTOR_BYTES)
    result[:12] = importer.SYNC
    result[15] = 2
    result[16:20] = result[20:24] = bytes([0, 0, 0x28 if form2 else 8, 0])
    result[24 : 24 + len(payload)] = payload
    return bytes(result)


def fixture(serial: str, form2: bool = False) -> tuple[bytes, str]:
    sectors = [raw_sector(b"") for _ in range(25)]
    config = f"BOOT = cdrom:\\MGS\\{serial};1\r\n".encode("ascii")
    executable = b"PS-X EXE" + serial.encode("ascii") + b"\x00" * 123
    mgs = record(b"\x00", 19, 2048, True) + record(b"\x01", 18, 2048, True)
    mgs += record(serial.encode("ascii") + b";1", 21, len(executable))
    mgs += record(b"STAGE.DIR;1", 22, 23)
    mgs += record(b"VOICE.DAT;1", 23, 2049)
    root = record(b"\x00", 18, 2048, True) + record(b"\x01", 18, 2048, True)
    root += record(b"MGS", 19, 2048, True) + record(b"SYSTEM.CNF;1", 20, len(config))
    pvd = bytearray(2048)
    pvd[:7] = b"\x01CD001\x01"
    pvd[80:88] = both(len(sectors), 4)
    pvd[128:132] = both(2048, 2)
    pvd[156:190] = record(b"\x00", 18, 2048, True)
    sectors[16] = raw_sector(pvd)
    sectors[18] = raw_sector(root)
    sectors[19] = raw_sector(mgs)
    sectors[20] = raw_sector(config)
    sectors[21] = raw_sector(executable)
    sectors[22] = raw_sector(b"stage-data" + b"\x00" * 13)
    sectors[23] = raw_sector(b"v" * 2324 if form2 else b"v" * 2048, form2)
    sectors[24] = raw_sector(b"x")
    return b"".join(sectors), hashlib.sha256(executable).hexdigest()


def write_fixture(source: Path, serial: str, form2: bool = False) -> tuple[Path, str]:
    image, digest = fixture(serial, form2)
    path = source / f"{serial}.bin"
    path.write_bytes(image)
    (source / f"{serial}.cue").write_text(
        f'FILE "{path.name}" BINARY\n  TRACK 01 MODE2/2352\n    INDEX 01 00:00:00\n',
        encoding="utf-8",
    )
    return path, digest


class DiscTests(unittest.TestCase):
    def test_catalogue_reads_real_extents_and_identity(self):
        image, digest = fixture("SLPM_862.47")
        disc = importer.Disc(io.BytesIO(image), len(image))
        entries = importer.catalogue(disc)
        with patch.dict(importer.EDITIONS, {"SLPM_862.47": ("disc1", digest)}):
            self.assertEqual(importer.identify(disc, entries), "SLPM_862.47")
        self.assertEqual(
            {entry.path for entry in entries},
            {"MGS/SLPM_862.47", "MGS/STAGE.DIR", "MGS/VOICE.DAT", "SYSTEM.CNF"},
        )

    def test_original_hash_required(self):
        image, _ = fixture("SLPM_862.47")
        disc = importer.Disc(io.BytesIO(image), len(image))
        with self.assertRaisesRegex(ValueError, "checksum"):
            importer.identify(disc, importer.catalogue(disc))

    def test_rejects_truncated_images_and_out_of_bounds_extents(self):
        image, _ = fixture("SLPM_862.47")
        with self.assertRaisesRegex(ValueError, "complete raw-sector"):
            importer.Disc(io.BytesIO(image[:-1]), len(image) - 1)
        disc = importer.Disc(io.BytesIO(image), len(image))
        with self.assertRaisesRegex(ValueError, "outside"):
            disc.read_metadata(24, 2049)

    def test_endian_disagreement_is_not_ignored(self):
        data = bytearray(record(b"SAFE;1", 22, 3))
        data[6] ^= 1
        with self.assertRaisesRegex(ValueError, "endian copies"):
            importer.directory_record(bytes(data), "")

    def test_rejects_bad_directory_records_and_paths(self):
        for name in [
            b"../BAD;1",
            b"C:BAD;1",
            b"NUL;1",
            b"COM1.TXT;1",
            b"TRAIL.;1",
            b"NAME;2",
        ]:
            with self.subTest(name=name), self.assertRaises(ValueError):
                importer.directory_record(record(name, 22, 4), "MGS")
        with self.assertRaisesRegex(ValueError, "record length"):
            importer.directory_record(b"\x22" * 20, "")

    def test_rejects_sector_subheader_disagreement(self):
        image, _ = fixture("SLPM_862.47")
        data = bytearray(image)
        data[16 * importer.SECTOR_BYTES + 20] = 7
        disc = importer.Disc(io.BytesIO(data), len(data))
        with self.assertRaisesRegex(ValueError, "subheader copies"):
            disc.root()

    def test_rejects_directory_cycle(self):
        image, _ = fixture("SLPM_862.47")
        data = bytearray(image)
        start = 19 * importer.SECTOR_BYTES
        data[start : start + importer.SECTOR_BYTES] = raw_sector(
            record(b"LOOP", 19, 2048, True)
        )
        disc = importer.Disc(io.BytesIO(data), len(data))
        with self.assertRaisesRegex(ValueError, "Cyclic"):
            importer.catalogue(disc)

    def test_form2_preserves_raw_stream_and_exact_logical_length(self):
        image, _ = fixture("SLPM_862.47", form2=True)
        disc = importer.Disc(io.BytesIO(image), len(image))
        entry = next(
            entry
            for entry in importer.catalogue(disc)
            if entry.path.endswith("VOICE.DAT")
        )
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            receipt = importer.extract_file(disc, entry, output)
            self.assertEqual(receipt["form2Sectors"], 1)
            self.assertEqual((output / entry.path).read_bytes(), b"v" * 2048 + b"x")
            self.assertEqual(
                (output / receipt["rawSectors"]["path"]).read_bytes(),
                image[23 * 2352 :],
            )


class ImportTests(unittest.TestCase):
    def test_cue_cannot_escape_or_hide_multiple_tracks(self):
        with tempfile.TemporaryDirectory() as temporary:
            cue = Path(temporary) / "disc.cue"
            for contents in [
                'FILE "../outside.bin" BINARY\nTRACK 01 MODE2/2352\nINDEX 01 00:00:00\n',
                'FILE "disc.bin" BINARY\nTRACK 01 MODE2/2352\nINDEX 01 00:00:00\nTRACK 02 AUDIO\n',
            ]:
                cue.write_text(contents, encoding="utf-8")
                with self.assertRaises(ValueError):
                    importer.cue_image(cue)

    def test_import_separates_discs_and_does_not_touch_source(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source"
            source.mkdir()
            identities = {}
            for serial, (name, _) in importer.EDITIONS.items():
                _, digest = write_fixture(source, serial)
                identities[serial] = (name, digest)
            before = {path.name: importer.file_hash(path) for path in source.iterdir()}
            output = root / "content"
            with (
                patch.dict(importer.EDITIONS, identities),
                redirect_stdout(io.StringIO()),
            ):
                result = importer.import_content(source, output)
            self.assertTrue(result["complete"])
            self.assertFalse((output / "incomplete.json").exists())
            self.assertEqual(len(result["discs"]), 3)
            for serial, (name, _) in identities.items():
                self.assertTrue((output / name / "MGS" / serial).is_file())
                receipt = json.loads(
                    (output / name / "manifest.json").read_text(encoding="utf-8")
                )
                self.assertEqual(receipt["serial"], serial)
            self.assertEqual(
                before,
                {path.name: importer.file_hash(path) for path in source.iterdir()},
            )
            with self.assertRaises(FileExistsError):
                importer.import_content(source, output)
            with self.assertRaisesRegex(ValueError, "separate"):
                importer.import_content(source, source / "converted")

    def test_identity_failure_leaves_no_output(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source"
            source.mkdir()
            for serial in importer.EDITIONS:
                write_fixture(source, serial)
            output = root / "content"
            with self.assertRaisesRegex(ValueError, "checksum"):
                importer.import_content(source, output)
            self.assertFalse(output.exists())

    def test_campaign_pair_selection_ignores_unselected_cues(self):
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary) / "source"
            source.mkdir()
            identities = {}
            cues = []
            for serial in ("SLPM_862.47", "SLPM_862.48"):
                image, digest = write_fixture(source, serial)
                identities[serial] = (importer.EDITIONS[serial][0], digest)
                cues.append(image.with_suffix(".cue"))
            (source / "another-edition.cue").write_text(
                "Not selected", encoding="utf-8"
            )
            with (
                patch.dict(importer.EDITIONS, identities),
                redirect_stdout(io.StringIO()),
            ):
                result = importer.import_content(
                    source, source.parent / "content", cues
                )
                self.assertEqual(
                    [disc["disc"] for disc in result["discs"]], ["disc1", "disc2"]
                )
                with self.assertRaisesRegex(ValueError, "Both Integral"):
                    other, other_hash = write_fixture(source, "SLPM_862.49")
                    with patch.dict(
                        importer.EDITIONS, {"SLPM_862.49": ("disc3", other_hash)}
                    ):
                        importer.plan_import(
                            source, [cues[0], other.with_suffix(".cue")]
                        )

    def test_duplicate_identity_is_rejected_before_output(self):
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary)
            image, digest = write_fixture(source, "SLPM_862.47")
            cue = image.with_suffix(".cue")
            for number in (2, 3):
                (source / f"copy{number}.cue").write_bytes(cue.read_bytes())
            with patch.dict(importer.EDITIONS, {"SLPM_862.47": ("disc1", digest)}):
                with self.assertRaisesRegex(ValueError, "Duplicate disc"):
                    importer.plan_import(source)


if __name__ == "__main__":
    unittest.main()
