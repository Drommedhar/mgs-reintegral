"""Independent input-prefix fixtures; no game window or source recording writes."""

import hashlib
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools/prepare-input-resume.py"
SPEC = importlib.util.spec_from_file_location("prepare_input_resume", TOOL)
if SPEC is None or SPEC.loader is None:
    raise ImportError(f"Cannot load {TOOL}")
RESUME = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = RESUME
SPEC.loader.exec_module(RESUME)

HEADER = b"MGSINPUT 1 " + b"0123456789abcdef" * 4 + b"\n"
PAD_ONE = bytes(range(34)).hex()
PAD_TWO = bytes(range(33, -1, -1)).hex()
XBOX = ROOT / ".local/replays/xbox-01.mgsinput"
XBOX_HASH = "1c0a6f36ff8ab1019f9e17c84ab999f42b587a5d84b25d7964a98fc008aeb1be"


def row(index, stage="s00a", *, load=1, request=0, pause=0, tick=None, kind="P"):
    state = [
        100 + index,
        load,
        request,
        pause,
        32,
        16,
        1,
        -400,
        900,
        1200,
        256,
        10,
        -1,
        -1,
        -1,
        128,
        1,
        0,
        0,
        256,
        -123456,
        0,
    ]
    fields = [
        kind,
        str(index),
        str(index + 4 if tick is None else tick),
        "115",
        "83",
        PAD_ONE,
        PAD_TWO,
        stage,
        *map(str, state),
    ]
    return (" ".join(fields) + "\n").encode("ascii")


def change_field(line, index, value):
    fields = line.split()
    fields[index] = value
    return b" ".join(fields) + b"\n"


class ResumeTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="mgs-resume-test-")
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.source = self.directory / "source.mgsinput"
        self.output = self.directory / "prefix.mgsinput"
        self.manifest = Path(str(self.output) + ".resume.json")

    def prepare(self, data):
        self.source.write_bytes(data)
        result = RESUME.prepare_input_resume(self.source, self.output)
        self.assertEqual(self.source.read_bytes(), data)
        self.assertEqual(json.loads(self.manifest.read_text()), result)
        self.assertEqual(result["source"]["sha256"], hashlib.sha256(data).hexdigest())
        self.assertEqual(
            result["prefix"]["sha256"],
            hashlib.sha256(self.output.read_bytes()).hexdigest(),
        )
        return result

    def test_latest_visit_uses_first_ready_packet_then_next_callback(self):
        rows = [
            row(0, "title"),
            row(1),
            row(2, "s01a", request=145),
            row(3, "s01a", pause=2),
            row(4, "s01a"),
            row(5, "s01a"),
        ]
        result = self.prepare(HEADER + b"".join(rows) + row(6, "s01a", kind="E"))
        lines = self.output.read_bytes().splitlines(keepends=True)
        self.assertEqual(lines[:-1], [HEADER, *rows[:5]])
        expected = b"E 5 9 255 255 " + b" ".join(rows[4].split()[5:]) + b"\n"
        self.assertEqual(lines[-1], expected)
        self.assertEqual(
            result["selected"],
            {"stage": "s01a", "visit_start_sample": 2, "sample": 4, "vsync": 8},
        )
        self.assertFalse(result["fallback"]["used"])
        self.assertTrue(result["source"]["has_footer"])
        self.assertFalse(result["source_completion_verified"])

    def test_missing_footer_and_partial_final_row_are_reported(self):
        tail = row(3, "s01a")[:173]
        result = self.prepare(HEADER + row(0, "title") + row(1) + row(2, "s01a") + tail)
        self.assertEqual(result["source"]["complete_samples"], 3)
        self.assertEqual(result["source"]["partial_bytes"], len(tail))
        self.assertFalse(result["source"]["has_footer"])
        self.assertEqual(result["selected"]["sample"], 2)

    def test_every_truncation_of_a_writer_row_preserves_only_complete_rows(self):
        complete = HEADER + row(0, "title") + row(1)
        for kind in ("P", "E"):
            following = row(2, "s01a", kind=kind)
            for length in range(1, len(following)):
                with self.subTest(kind=kind, length=length):
                    scan = RESUME.inspect_data(complete + following[:length])
                    self.assertEqual(scan.complete_samples, 2)
                    self.assertEqual(scan.partial_bytes, length)
                    self.assertFalse(scan.has_footer)
                    self.assertEqual(RESUME.selected_visit(scan).stage, "s00a")

    def test_eof_on_complete_line_is_distinct_from_truncated_row(self):
        result = self.prepare(HEADER + row(0, "title") + row(1))
        self.assertFalse(result["source"]["has_footer"])
        self.assertEqual(result["source"]["partial_bytes"], 0)

    def test_loading_final_stage_falls_back_to_previous_ready_visit(self):
        result = self.prepare(HEADER + row(0) + row(1, "s01a", request=145))
        self.assertEqual(result["selected"]["stage"], "s00a")
        self.assertEqual(result["source"]["last_stage"], "s01a")
        self.assertTrue(result["fallback"]["used"])
        self.assertIn("no eligible loaded", result["fallback"]["reason"])

    def test_stage_revisit_and_same_name_reload_select_the_new_visit(self):
        recordings = [
            HEADER + row(0) + row(1, "d00a") + row(2, request=1) + row(3) + row(4),
            HEADER + row(0) + row(1, load=0) + row(2, request=1) + row(3) + row(4),
        ]
        for data in recordings:
            with self.subTest(data=data):
                visit = RESUME.selected_visit(RESUME.inspect_data(data))
                self.assertEqual(visit.boundary.sample, 3)
                self.assertGreater(visit.start_sample, 0)

    def test_pause_does_not_create_a_new_loaded_stage_visit(self):
        result = self.prepare(HEADER + row(0) + row(1, pause=1) + row(2))
        self.assertEqual(result["selected"]["sample"], 0)

    def test_only_campaign_stage_names_qualify(self):
        for stage in (
            "title",
            "opening",
            "select",
            "s01",
            "d01",
            "s1a",
            "s01A",
            "-",
            "s01a2x",
        ):
            with self.subTest(stage=stage):
                scan = RESUME.inspect_data(HEADER + row(0, stage))
                if stage == "s01a2x":
                    self.assertEqual(RESUME.selected_visit(scan).stage, stage)
                else:
                    with self.assertRaisesRegex(ValueError, "No fully loaded"):
                        RESUME.selected_visit(scan)
        self.assertEqual(
            RESUME.selected_visit(RESUME.inspect_data(HEADER + row(0, "d18ar"))).stage,
            "d18ar",
        )

    def test_no_eligible_boundary_produces_no_files(self):
        self.source.write_bytes(HEADER + row(0, "title") + row(1, request=1))
        with self.assertRaisesRegex(ValueError, "No fully loaded"):
            RESUME.prepare_input_resume(self.source, self.output)
        self.assertFalse(self.output.exists())
        self.assertFalse(self.manifest.exists())

    def test_crlf_source_bytes_preserved(self):
        data = (HEADER + row(0, "title") + row(1)).replace(b"\n", b"\r\n")
        self.prepare(data)
        self.assertTrue(self.output.read_bytes().startswith(data))
        self.assertTrue(RESUME.inspect_data(self.output.read_bytes()).has_footer)

    def test_reject_malformed_complete_records_including_after_selection(self):
        bad_rows = [
            change_field(row(1), 0, b"Q"),
            change_field(row(1), 1, b"2"),
            change_field(row(1), 2, b"3"),
            change_field(row(1), 3, b"116"),
            change_field(row(1), 4, b"-1"),
            change_field(row(1), 5, b"00"),
            change_field(row(1), 6, b"A" * 68),
            change_field(row(1), 7, b"s00a/b"),
            change_field(row(1), 7, b"s" * 16),
            change_field(row(1), 8, b"2147483648"),
            change_field(row(1), 8, b"-2147483649"),
            change_field(row(1), 1, b"+1"),
            row(1).replace(b" ", b"\t", 1),
            row(1)[:-1] + b" extra\n",
            b"P 1\n",
            row(1).replace(b"P", b"\0", 1),
            b"x" * 512 + b"\n",
        ]
        for line in bad_rows:
            with self.subTest(line=line), self.assertRaises(ValueError):
                RESUME.inspect_data(HEADER + row(0) + line)

    def test_reject_bad_header_footer_and_partial_garbage(self):
        bad_data = [
            b"",
            HEADER[:-1],
            HEADER.replace(b" 1 ", b" 2 "),
            HEADER[:-1] + b"\r\r\n",
            HEADER.replace(b"a", b"A", 1),
            HEADER + row(0) + b"P garbage",
            HEADER + row(0) + b"P 3 ",
            HEADER + row(0) + b"P 1 2 ",
            HEADER + row(0) + b"garbage",
            HEADER + row(0) + row(1, kind="E") + b"P",
            HEADER + row(0) + row(2, kind="E"),
        ]
        for data in bad_data:
            with self.subTest(data=data), self.assertRaises(ValueError):
                RESUME.inspect_data(data)

    def test_no_overwrite_alias_or_session_mutation(self):
        data = HEADER + row(0)
        self.source.write_bytes(data)
        self.manifest.write_bytes(b"preserve")
        with self.assertRaises(ValueError):
            RESUME.prepare_input_resume(self.source, self.output)
        self.assertFalse(self.output.exists())
        self.assertEqual(self.manifest.read_bytes(), b"preserve")
        self.manifest.unlink()
        for output, manifest in (
            (self.source, self.manifest),
            (self.output, self.output),
        ):
            with self.subTest(output=output, manifest=manifest):
                with self.assertRaises(ValueError):
                    RESUME.prepare_input_resume(self.source, output, manifest)
        os.link(self.source, self.output)
        with self.assertRaises(ValueError):
            RESUME.prepare_input_resume(self.source, self.output)
        self.assertEqual(self.source.read_bytes(), data)
        session = Path(str(self.source) + ".session")
        session.mkdir()
        with self.assertRaisesRegex(ValueError, "session"):
            RESUME.prepare_input_resume(self.source, session / "new.input")
        self.assertEqual(list(session.iterdir()), [])

    def test_failed_second_output_open_removes_only_new_prefix(self):
        data = HEADER + row(0)
        self.source.write_bytes(data)
        with self.assertRaises(FileNotFoundError):
            RESUME.prepare_input_resume(
                self.source, self.output, self.directory / "missing/report.json"
            )
        self.assertFalse(self.output.exists())
        self.assertEqual(self.source.read_bytes(), data)

    def test_counter_overflow_is_rejected_without_output(self):
        self.source.write_bytes(HEADER + row(0, tick=4294967295))
        with self.assertRaisesRegex(ValueError, "overflow"):
            RESUME.prepare_input_resume(self.source, self.output)
        self.assertFalse(self.output.exists())

    def test_cli_generates_manifest_and_refuses_existing_output(self):
        self.source.write_bytes(HEADER + row(0))
        command = [
            sys.executable,
            str(TOOL),
            str(self.source),
            "--output",
            str(self.output),
        ]
        first = subprocess.run(
            command, capture_output=True, text=True, check=False, timeout=10
        )
        self.assertEqual(first.returncode, 0, first.stderr)
        self.assertEqual(json.loads(first.stdout)["selected"]["sample"], 0)
        previous = self.output.read_bytes()
        second = subprocess.run(
            command, capture_output=True, text=True, check=False, timeout=10
        )
        self.assertEqual(second.returncode, 2)
        self.assertEqual(self.output.read_bytes(), previous)

    @unittest.skipUnless(XBOX.exists(), "Private Xbox crash recording is unavailable")
    def test_actual_xbox_source_and_derived_boundary(self):
        original = XBOX.read_bytes()
        self.assertEqual(hashlib.sha256(original).hexdigest(), XBOX_HASH)
        result = RESUME.prepare_input_resume(XBOX, self.output)
        lines = original.splitlines(keepends=True)
        self.assertEqual(len(lines) - 2, 15675)
        self.assertEqual(result["source"]["complete_samples"], 15675)
        self.assertEqual(result["source"]["partial_bytes"], 172)
        self.assertEqual(
            result["selected"],
            {
                "stage": "s01a",
                "visit_start_sample": 12922,
                "sample": 13152,
                "vsync": 13156,
            },
        )
        output = self.output.read_bytes().splitlines(keepends=True)
        self.assertEqual(output[:-1], lines[:13154])
        self.assertEqual(
            output[-1],
            b"E 13153 13157 255 255 " + b" ".join(lines[13153].split()[5:]) + b"\n",
        )
        self.assertEqual(RESUME.inspect_data(b"".join(output)).complete_samples, 13153)
        self.assertEqual(XBOX.read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
