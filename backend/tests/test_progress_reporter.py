"""Tests for progress_reporter.py — ADB parsing and NDJSON emission (RED phase)."""
import json
import unittest
from unittest.mock import patch


class TestAdbProgressParsing(unittest.TestCase):
    """Pure function: parse_adb_progress from ADB stderr lines."""

    def test_parse_modern_adb_line(self):
        """Parses modern ADB output with all fields."""
        from backend.progress_reporter import parse_adb_progress

        line = "45% 12.3 MB/s 2.1GB/4.7GB 00:12"
        result = parse_adb_progress(line)
        self.assertIsNotNone(result)
        self.assertEqual(result["percentage"], 45)
        self.assertGreater(result["bytesTransferred"], 0)
        self.assertGreater(result["bytesTotal"], 0)
        self.assertGreater(result["transferRateBps"], 0)

    def test_parse_legacy_adb_line(self):
        """Parses ADB output with different formatting."""
        from backend.progress_reporter import parse_adb_progress

        line = "12% 5.0 MB/s 600.0MB/5.0GB 00:45"
        result = parse_adb_progress(line)
        self.assertIsNotNone(result)
        self.assertEqual(result["percentage"], 12)

    def test_parse_no_match_returns_none(self):
        """Non-matching line returns None."""
        from backend.progress_reporter import parse_adb_progress

        result = parse_adb_progress("adb: error: failed to copy file.txt")
        self.assertIsNone(result)

    def test_parse_empty_string(self):
        """Empty string returns None."""
        from backend.progress_reporter import parse_adb_progress

        result = parse_adb_progress("")
        self.assertIsNone(result)


class TestEtaEstimation(unittest.TestCase):
    """Pure function: estimate_eta calculation."""

    def test_eta_at_50_percent(self):
        """At 50% progress after 60s, ETA should be ~60s."""
        from backend.progress_reporter import estimate_eta

        eta = estimate_eta(50.0, 60)
        self.assertEqual(eta, 60)

    def test_eta_at_25_percent(self):
        """At 25% after 30s, ETA should be ~90s."""
        from backend.progress_reporter import estimate_eta

        eta = estimate_eta(25.0, 30)
        self.assertEqual(eta, 90)

    def test_eta_zero_when_no_progress(self):
        """ETA is 0 when no progress made."""
        from backend.progress_reporter import estimate_eta

        eta = estimate_eta(0.0, 30)
        self.assertEqual(eta, 0)

    def test_eta_never_negative(self):
        """ETA never drops below 0."""
        from backend.progress_reporter import estimate_eta

        eta = estimate_eta(100.0, 60)
        self.assertEqual(eta, 0)


class TestProgressReporter(unittest.TestCase):
    """ProgressReporter NDJSON output."""

    @patch("backend.progress_reporter.sys.stdout")
    def test_emit_progress_writes_ndjson(self, mock_stdout):
        """emit_progress writes valid NDJSON to stdout."""
        from backend.progress_reporter import ProgressReporter

        reporter = ProgressReporter("t1")
        reporter.emit_progress(
            phase="pull", package="com.whatsapp",
            item="Databases/msgstore.db.crypt14",
            bytes_transferred=1000, bytes_total=5000,
            percentage=20.0, transfer_rate_bps=12_000_000,
            eta_seconds=320,
        )

        self.assertTrue(mock_stdout.write.called)
        written = mock_stdout.write.call_args[0][0]
        data = json.loads(written)
        self.assertEqual(data["type"], "progress")
        self.assertEqual(data["phase"], "pull")
        self.assertEqual(data["percentage"], 20.0)

    @patch("backend.progress_reporter.sys.stdout")
    def test_emit_phase_change_writes_ndjson(self, mock_stdout):
        """emit_phase_change writes valid NDJSON to stdout."""
        from backend.progress_reporter import ProgressReporter

        reporter = ProgressReporter("t1")
        reporter.emit_phase_change(from_="pull", to="push")

        written = mock_stdout.write.call_args[0][0]
        data = json.loads(written)
        self.assertEqual(data["type"], "phase_change")
        self.assertEqual(data["from"], "pull")
        self.assertEqual(data["to"], "push")


if __name__ == "__main__":
    unittest.main()
