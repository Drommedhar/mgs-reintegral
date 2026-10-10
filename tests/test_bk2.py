"""BK2 validation and lossless frame slicing, without native playback."""

import csv
import hashlib
import io
import json
import tempfile
import unittest
import zipfile
from pathlib import Path

from tools.inspect_bk2 import (
    BUTTONS,
    CSV_COLUMNS,
    LOG_KEY,
    SYNC_TYPE,
    inspect_movie,
    iter_frames,
    parse_controllers,
    parse_header,
)

HEADER = (
    "MovieVersion BizHawk v2.0.0\nPlatform PSX\nCore Octoshock\n"
    "Author Synthetic Test Author\nemuVersion Version 1.11.4"
)
BUTTON_ORDER = (
    "Up",
    "Down",
    "Left",
    "Right",
    "Select",
    "Start",
    "Square",
    "Triangle",
    "Circle",
    "Cross",
    "L1",
    "R1",
    "L2",
    "R2",
    "L3",
    "R3",
    "MODE",
)
LOCAL_MOVIE = (
    Path(__file__).resolve().parents[1]
    / ".local/replays/theenglishman-mgs-integral-all-bosses.bk2"
)


def settings() -> dict:
    return {
        "o": {
            "$type": SYNC_TYPE,
            "EnableLEC": False,
            "FIOConfig": {
                "Multitaps": [False, False],
                "Memcards": [True, True],
                "Devices8": [3, 0, 0, 0, 2, 0, 0, 0],
            },
        }
    }


def row(
    buttons1: str = "." * 17,
    buttons2: str = "." * 17,
    axes1: str = "  128,  128,  128,  128",
    axes2: str = "  128,  128,  128,  128",
    system: str = "    1,...",
) -> str:
    return f"|{system}|{axes1},{buttons1}|{axes2},{buttons2}|\n"


def movie(
    path: Path,
    rows: str,
    header: str = HEADER,
    config: dict | None = None,
    key: str = LOG_KEY,
    extra: dict[str, bytes] | None = None,
) -> None:
    with zipfile.ZipFile(path, "w") as archive:
        archive.writestr("Header.txt", header)
        archive.writestr(
            "SyncSettings.json", json.dumps(settings() if config is None else config)
        )
        archive.writestr("Input Log.txt", key + "\r\n" + rows)
        for name, data in (extra or {}).items():
            archive.writestr(name, data)


class FrameParserTests(unittest.TestCase):
    def test_all_named_buttons_both_ports_and_noncanonical_markers(self):
        self.assertEqual(BUTTONS, BUTTON_ORDER)
        lines = [LOG_KEY + "\n"]
        for index in range(17):
            first = "." * index + "?" + "." * (16 - index)
            second = "." * (16 - index) + "é" + "." * index
            lines.append(row(first, second))
        frames = list(iter_frames(lines))
        for index, frame in enumerate(frames):
            self.assertEqual(frame.index, index)
            for port, active in ((0, index), (1, 16 - index)):
                pressed = [
                    BUTTON_ORDER[i]
                    for i, value in enumerate(frame.pads[port].buttons)
                    if value
                ]
                self.assertEqual(pressed, [BUTTON_ORDER[active]])

    def test_axis_order_extremes_system_controls_and_csv_mapping(self):
        frame = next(
            iter_frames(
                [
                    LOG_KEY,
                    row(
                        axes1="    0,  255,    1,  254",
                        axes2="  127,  128,   42,  200",
                        system="    2,!?R",
                    ),
                ]
            )
        )
        mapped = dict(zip(CSV_COLUMNS, frame.csv_row()))
        self.assertEqual(frame.pads[0].axes, (0, 255, 1, 254))
        self.assertEqual(frame.pads[1].axes, (127, 128, 42, 200))
        self.assertEqual(
            (mapped["disc_select"], mapped["open"], mapped["close"], mapped["reset"]),
            (2, 1, 1, 1),
        )
        self.assertEqual(mapped["p1_rstick_y"], 254)
        self.assertEqual(mapped["p2_lstick_x"], 127)
        self.assertEqual(len(mapped), 47)

    def test_neutral_duplicate_rows_and_blank_lines_are_retained(self):
        frames = list(
            iter_frames(["\n", LOG_KEY + "\r\n", row(), row(), "\r\n", row()])
        )
        self.assertEqual([frame.index for frame in frames], [0, 1, 2])
        self.assertEqual(frames[0].pads, frames[2].pads)

    def test_invalid_input_fails_instead_of_dropping_fields_or_frames(self):
        cases = [
            (LOG_KEY.replace("P2 MODE", "P2 Unknown"), row()),
            (LOG_KEY.replace("P1 Up|P1 Down", "P1 Down|P1 Up"), row()),
            (LOG_KEY, row(axes1="  256,  128,  128,  128")),
            (LOG_KEY, row(axes2="   -1,  128,  128,  128")),
            (LOG_KEY, row(axes1="128.0,  128,  128,  128")),
            (LOG_KEY, row(buttons1="." * 16)),
            (LOG_KEY, row(system="    1,..")),
            (LOG_KEY, row(system="   -1,...")),
            (LOG_KEY, row().rstrip() + "extra\n"),
            (LOG_KEY, "unrecognized data\n"),
            (LOG_KEY, ""),
        ]
        for key, data in cases:
            with self.subTest(data=data, key=key), self.assertRaises(ValueError):
                list(iter_frames(io.StringIO(key + "\n" + data)))

    def test_error_reports_original_frame_and_line(self):
        with self.assertRaisesRegex(ValueError, "line 4, frame 2"):
            list(iter_frames([LOG_KEY, row(), row(), row(buttons2="bad")]))


class SchemaTests(unittest.TestCase):
    def test_attribution_and_both_controller_types(self):
        self.assertEqual(parse_header(HEADER)["Author"], "Synthetic Test Author")
        original, pads = parse_controllers(json.dumps(settings()))
        self.assertEqual(original, settings())
        self.assertEqual([pad["device"] for pad in pads], ["DualAnalog", "DualShock"])
        self.assertEqual(pads[1]["buttons"], list(BUTTON_ORDER))

    def test_unsupported_platform_core_version_and_duplicate_header(self):
        cases = [
            HEADER.replace("Platform PSX", "Platform NES"),
            HEADER.replace("Core Octoshock", "Core Other"),
            HEADER.replace("BizHawk v2.0.0", "BizHawk v1.0.0"),
            HEADER + "\nPlatform PSX",
            HEADER + "\nStartsFromSaveRam sometimes",
        ]
        for text in cases:
            with self.subTest(text=text), self.assertRaises(ValueError):
                parse_header(text)

    def test_unsupported_device_and_multitap_schemas(self):
        for field, value in (
            ("Multitaps", [True, False]),
            ("Multitaps", [0, 0]),
            ("Memcards", [True]),
            ("Memcards", [1, 1]),
            ("Devices8", [1, 0, 0, 0, 3, 0, 0, 0]),
            ("Devices8", [3, 3, 0, 0, 3, 0, 0, 0]),
            ("Devices8", [3, 0, 0, 0, 0, 0, 0, 0]),
            ("Devices8", [3.0, 0, 0, 0, 3, 0, 0, 0]),
            ("Unknown", True),
        ):
            config = settings()
            config["o"]["FIOConfig"][field] = value
            with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                parse_controllers(json.dumps(config))
        for config in ([], {"o": None}, {"o": {}}, {"different": {}}):
            with self.subTest(config=config), self.assertRaises(ValueError):
                parse_controllers(json.dumps(config))


class ArchiveTests(unittest.TestCase):
    def test_slice_keeps_frame_indices_hashes_attribution_and_private_ram(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source, output = root / "input.bk2", root / "slice.csv"
            ram = b"synthetic memory-card bytes"
            movie(
                source,
                row() + row(system="    0,!..") + row(system="    2,.!.") + row(),
                header=HEADER + "\nStartsFromSaveRam True",
                extra={"MovieSaveRam.bin": ram, "../untrusted.txt": b"never extract"},
            )
            metadata = inspect_movie(source, 1, 3, output)
            with output.open(newline="", encoding="utf8") as handle:
                rows = list(csv.DictReader(handle))
            self.assertEqual([entry["frame"] for entry in rows], ["1", "2"])
            self.assertEqual([entry["disc_select"] for entry in rows], ["0", "2"])
            self.assertEqual(metadata["frames"], 4)
            self.assertEqual(metadata["slice_frames"], 2)
            self.assertEqual(metadata["author"], "Synthetic Test Author")
            self.assertEqual(
                metadata["source_sha256"],
                hashlib.sha256(source.read_bytes()).hexdigest(),
            )
            self.assertEqual(
                metadata["save_ram"]["sha256"], hashlib.sha256(ram).hexdigest()
            )
            sidecar = output.with_name(output.name + ".metadata.json")
            self.assertEqual(json.loads(sidecar.read_text(encoding="utf8")), metadata)
            self.assertNotIn(ram.decode(), sidecar.read_text(encoding="utf8"))
            self.assertEqual(
                {p.name for p in root.iterdir()},
                {"input.bk2", "slice.csv", "slice.csv.metadata.json"},
            )

    def test_bad_later_frame_prevents_even_an_earlier_slice_export(self):
        with tempfile.TemporaryDirectory() as temporary:
            source, output = (
                Path(temporary) / "input.bk2",
                Path(temporary) / "slice.csv",
            )
            movie(source, row() + row(axes1="  999,  128,  128,  128"))
            with self.assertRaisesRegex(ValueError, "frame 1"):
                inspect_movie(source, 0, 1, output)
            self.assertFalse(output.exists())

    def test_slice_bounds_are_explicit_and_do_not_clamp(self):
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary) / "input.bk2"
            movie(source, row() + row())
            for start, end in ((-1, 1), (1, 1), (0, 3), (2, None)):
                with self.subTest(start=start, end=end), self.assertRaises(ValueError):
                    inspect_movie(source, start, end)

    def test_existing_csv_or_metadata_is_not_overwritten(self):
        with tempfile.TemporaryDirectory() as temporary:
            source, output = (
                Path(temporary) / "input.bk2",
                Path(temporary) / "slice.csv",
            )
            movie(source, row())
            for target in (output, output.with_name(output.name + ".metadata.json")):
                target.write_text("keep", encoding="utf8")
                with self.assertRaises(FileExistsError):
                    inspect_movie(source, output=output)
                self.assertEqual(target.read_text(encoding="utf8"), "keep")
                if target != output:
                    self.assertFalse(output.exists())
                target.unlink()

    def test_declared_ram_missing_and_duplicate_members_fail(self):
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(temporary) / "input.bk2"
            movie(source, row(), header=HEADER + "\nStartsFromSaveRam True")
            with self.assertRaisesRegex(ValueError, "MovieSaveRam.bin is missing"):
                inspect_movie(source)
            with zipfile.ZipFile(source, "a") as archive, self.assertWarns(UserWarning):
                archive.writestr("Header.txt", HEADER)
            with self.assertRaisesRegex(ValueError, "duplicate member"):
                inspect_movie(source)


@unittest.skipUnless(LOCAL_MOVIE.is_file(), "Optional user-local TAS movie is absent")
class LocalMovieTests(unittest.TestCase):
    def test_original_movie_count_and_disc_transition_slice(self):
        start, end = 181880, 181910
        with zipfile.ZipFile(LOCAL_MOVIE) as archive:
            raw_rows = [
                line
                for line in archive.read("Input Log.txt").splitlines()
                if line.startswith(b"|")
            ]
        self.assertEqual(len(raw_rows), 313202)
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "disc-change.csv"
            metadata = inspect_movie(LOCAL_MOVIE, start, end, output)
            self.assertEqual(metadata["frames"], len(raw_rows))
            self.assertEqual(
                metadata["source_sha256"],
                "8f433916cb219a243499f75b92f6a90d3f5333b671e53a846f37dc5733732a7a",
            )
            self.assertEqual(metadata["author"], "theenglishman")
            self.assertEqual(metadata["save_ram"]["bytes"], 262144)
            with output.open(newline="", encoding="utf8") as handle:
                converted = list(csv.DictReader(handle))
            self.assertEqual(len(converted), end - start)
            for index, fields in enumerate(converted, start):
                groups = raw_rows[index].decode().split("|")
                disc, events = groups[1].split(",")
                expected = [index, int(disc), *(int(c != ".") for c in events)]
                for group in groups[2:4]:
                    values = group.split(",")
                    expected.extend(int(value) for value in values[:4])
                    expected.extend(int(c != ".") for c in values[4])
                self.assertEqual([int(value) for value in fields.values()], expected)
            self.assertEqual(converted[3]["open"], "1")
            self.assertEqual(converted[13]["disc_select"], "2")
            self.assertEqual(converted[26]["close"], "1")


if __name__ == "__main__":
    unittest.main()
