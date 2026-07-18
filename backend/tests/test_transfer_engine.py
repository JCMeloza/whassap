"""Tests for transfer_engine.py — pull→temp→push orchestration (RED phase)."""
import unittest
from unittest.mock import MagicMock, patch, call


class TestPackageMapping(unittest.TestCase):
    """Pure function: _map_packages matching logic."""

    def test_maps_one_to_one_matching(self):
        """Identical package lists map 1:1."""
        from backend.transfer_engine import _map_packages

        mapped, warnings = _map_packages(
            ["com.whatsapp", "com.whatsapp.w4b"],
            ["com.whatsapp", "com.whatsapp.w4b"],
        )
        self.assertEqual(mapped, {"com.whatsapp": "com.whatsapp",
                                   "com.whatsapp.w4b": "com.whatsapp.w4b"})
        self.assertEqual(len(warnings), 0)

    def test_partial_mapping_with_warning(self):
        """Partial mapping produces warnings for unmapped packages."""
        from backend.transfer_engine import _map_packages

        mapped, warnings = _map_packages(
            ["com.whatsapp", "com.whatsapp.w4b"],
            ["com.whatsapp"],  # dest has only WhatsApp
        )
        self.assertEqual(mapped, {"com.whatsapp": "com.whatsapp"})
        self.assertEqual(len(warnings), 1)
        self.assertIn("com.whatsapp.w4b", warnings[0])

    def test_no_match_returns_empty(self):
        """No matching packages returns empty mapping."""
        from backend.transfer_engine import _map_packages

        mapped, warnings = _map_packages(
            ["com.whatsapp"],
            [],  # dest has no WhatsApp packages
        )
        self.assertEqual(mapped, {})
        self.assertEqual(len(warnings), 1)


class TestTransferEngine(unittest.TestCase):
    """TransferEngine orchestration flow."""

    def setUp(self):
        from backend.transfer_engine import TransferEngine
        from backend.models import TransferConfig

        self.mock_adb = MagicMock(adb_path="/usr/bin/adb")
        self.mock_scanner = MagicMock()
        self.mock_temp = MagicMock()
        self.mock_reporter = MagicMock()
        self.mock_device = MagicMock()
        self.engine = TransferEngine(
            self.mock_adb, self.mock_scanner, self.mock_temp,
            self.mock_reporter, self.mock_device,
        )
        self.config = TransferConfig(
            sourceSerial="src123",
            destSerial="dst456",
            packages=["com.whatsapp"],
            items=["Databases/msgstore.db.crypt14"],
        )

    @patch("backend.transfer_engine.Path")
    def test_start_creates_temp_and_scans(self, mock_path):
        """Start creates temp dir, scans source, maps packages."""
        from backend.models import WhatsAppData, DatabaseInfo

        self.mock_device.get_properties.side_effect = [
            {"apiLevel": 29, "model": "Pixel 5"},
            {"apiLevel": 33, "model": "Pixel 8"},
        ]
        self.mock_device.detect_packages.return_value = ["com.whatsapp"]
        self.mock_scanner.scan_device.return_value = [
            WhatsAppData(
                databases=[DatabaseInfo("a", "a", 100, "com.whatsapp")],
                media=[],
                package="com.whatsapp",
            ),
        ]
        self.mock_temp.temp_dir = MagicMock()

        transfer_id = self.engine.start(self.config)

        self.mock_temp.create.assert_called_once()
        self.mock_scanner.scan_device.assert_called_once()
        self.assertEqual(self.mock_reporter.emit_phase_change.call_count, 4)

    def test_pause_stops_subprocess(self):
        """Pause sends SIGINT to running subprocess."""
        proc = MagicMock()
        proc.poll.return_value = None  # process is still running
        self.engine._process = proc
        self.engine._transfer_id = "t1"

        self.engine.pause("t1")

        proc.send_signal.assert_called_once()

    def test_pause_no_process(self):
        """Pause with no running process does not error."""
        self.engine._process = None
        self.engine.pause("t1")  # Should not raise

    def test_cancel_kills_process_and_cleans(self):
        """Cancel kills process and cleans temp dir."""
        proc = MagicMock()
        proc.poll.return_value = None  # process is still running
        self.engine._process = proc
        self.engine._transfer_id = "t1"

        self.engine.cancel("t1")

        proc.kill.assert_called_once()
        self.mock_temp.cleanup.assert_called_once()
        self.assertIsNone(self.engine._process)

    def test_cancel_no_process(self):
        """Cancel without running process still cleans temp."""
        self.engine._process = None
        self.engine.cancel("t1")
        self.mock_temp.cleanup.assert_called_once()


if __name__ == "__main__":
    unittest.main()
