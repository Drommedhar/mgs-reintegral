"""Regression checks for recorded/replayed host timing comparison."""

import csv
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from analyze_performance import compare, summarize


class PerformanceTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)

    def write(self, name, frames):
        path = self.root / name
        with path.open("w", newline="") as stream:
            writer = csv.writer(stream)
            writer.writerow(
                (
                    "vsync",
                    "stage",
                    "game_tick",
                    "input_sample",
                    "frame_us",
                    "draw_us",
                    "target_us",
                    "audio_empty_refills",
                )
            )
            writer.writerows(frames)
        return path

    def test_timing_differences_do_not_change_input_alignment(self):
        original = [
            (1, "d00a", 40, 0, 16683, 3000, 16683, 0),
            (2, "d00a", 41, 1, 40000, 4000, 16683, 1),
        ]
        replay = [
            (1, "d00a", 40, 0, 30000, 8000, 16683, 0),
            (2, "d00a", 41, 1, 17000, 5000, 16683, 0),
        ]
        first = self.write("record.csv", original)
        second = self.write("replay.csv", replay)
        report = compare(first, second)
        self.assertEqual(report["aligned_samples"], 2)
        self.assertEqual(report["mismatched_samples"], 0)
        self.assertEqual(report["aligned_frames_over_5ms_slower"], 1)
        stage = summarize(first)["stages"]["d00a"]
        self.assertEqual(stage["max_ms"], 40)
        self.assertEqual(stage["audio_empty_refill_counter_increase"], 1)
        self.assertEqual(stage["over_budget_plus_2ms"], 1)

    def test_divergence_and_incomplete_replay_are_reported(self):
        first = self.write(
            "record.csv",
            [
                (1, "d00a", 40, 0, 16000, 1000, 16683, 0),
                (2, "d00a", 41, 1, 16000, 1000, 16683, 0),
            ],
        )
        second = self.write("replay.csv", [(1, "s00a", 40, 0, 16000, 1000, 16683, 0)])
        report = compare(first, second)
        self.assertEqual(report["aligned_samples"], 0)
        self.assertEqual(report["mismatched_samples"], 1)
        self.assertEqual(report["reference_only_logged_frames"], 1)

    def test_sparse_spikes_join_by_vsync_instead_of_row_number(self):
        first = self.write(
            "record.csv",
            [
                (10, "d00a", 40, 8, 25000, 1000, 16683, 0),
                (15, "d00a", 42, 13, 40000, 1000, 16683, 0),
            ],
        )
        second = self.write(
            "replay.csv",
            [
                (15, "d00a", 42, 13, 25000, 1000, 16683, 0),
                (20, "d00a", 45, 18, 30000, 1000, 16683, 0),
            ],
        )
        report = compare(first, second)
        self.assertEqual(report["aligned_samples"], 1)
        self.assertEqual(report["mismatched_samples"], 0)
        self.assertEqual(report["reference_only_logged_frames"], 1)
        self.assertEqual(report["replay_only_logged_frames"], 1)

    def test_truncated_crash_row_is_not_counted_as_valid(self):
        path = self.write("crash.csv", [(1, "d00a", 40)])
        with self.assertRaisesRegex(ValueError, "Incomplete timing row"):
            summarize(path)


if __name__ == "__main__":
    unittest.main()
