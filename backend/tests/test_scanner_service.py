"""Tests for scanner_service.py — WhatsApp data discovery (RED phase)."""
import unittest
from unittest.mock import MagicMock, patch


LS_DB_LEGACY = """-rw-rw---- 1 u0_a123 u0_a123 50000000 2024-01-01 12:00 msgstore.db.crypt14
-rw-rw---- 1 u0_a123 u0_a123 2000000 2024-01-01 12:00 wa.db.crypt14
"""

LS_DB_LEGACY_BUSINESS = """-rw-rw---- 1 u0_a123 u0_a123 30000000 2024-01-01 12:00 msgstore.db.crypt14
"""

LS_DB_EMPTY = """"""

DU_MEDIA = """2100000000\t/sdcard/WhatsApp/Media/Images
850000000\t/sdcard/WhatsApp/Media/Video
"""

DU_MEDIA_SCOPED = """1500000000\t/sdcard/Android/media/com.whatsapp/WhatsApp/Media/Images
600000000\t/sdcard/Android/media/com.whatsapp/WhatsApp/Media/Video
"""

DU_MEDIA_EMPTY = """"""

LS_ONLY_DIRS = """drwxrwx--x 2 u0_a123 u0_a123 4092 2024-01-01 12:00 Databases
"""


class TestFileSizeParsing(unittest.TestCase):
    """Pure function: _parse_file_sizes from ls -la output."""

    def test_parses_db_files_with_sizes(self):
        """Parses .crypt14 files with correct sizes."""
        from backend.scanner_service import _parse_file_sizes

        files = _parse_file_sizes(LS_DB_LEGACY)
        self.assertEqual(len(files), 2)
        self.assertEqual(files[0][2], 50_000_000)
        self.assertEqual(files[0][0], "msgstore.db.crypt14")
        self.assertEqual(files[1][2], 2_000_000)

    def test_skips_directories(self):
        """Directories are excluded from file list."""
        from backend.scanner_service import _parse_file_sizes

        files = _parse_file_sizes(LS_ONLY_DIRS)
        self.assertEqual(len(files), 0)

    def test_empty_output_returns_empty(self):
        """Empty ls output produces empty list."""
        from backend.scanner_service import _parse_file_sizes

        files = _parse_file_sizes("")
        self.assertEqual(len(files), 0)


class TestMediaSizeParsing(unittest.TestCase):
    """Pure function: _parse_media_sizes from du -sb output."""

    def test_parses_media_categories(self):
        """Parses du output with size and path."""
        from backend.scanner_service import _parse_media_sizes

        items = _parse_media_sizes(DU_MEDIA)
        self.assertEqual(len(items), 2)
        self.assertEqual(items[0][2], 2_100_000_000)
        self.assertEqual(items[0][0], "Images")

    def test_empty_output_returns_empty(self):
        """Empty du output produces empty list."""
        from backend.scanner_service import _parse_media_sizes

        items = _parse_media_sizes("")
        self.assertEqual(len(items), 0)


class TestScannerService(unittest.TestCase):
    """ScannerService with mocked ADB interactions."""

    def setUp(self):
        from backend.scanner_service import ScannerService

        self.mock_adb = MagicMock(adb_path="/usr/bin/adb")
        self.scanner = ScannerService(self.mock_adb)

    @patch("backend.scanner_service._run_adb_shell")
    def test_legacy_scan_finds_databases_and_media(self, mock_run):
        """Legacy scan (API 29) returns DB + media for com.whatsapp."""
        def side_effect(adb_path, serial, cmd):
            if "Databases" in cmd and "WhatsApp/" in cmd:
                return LS_DB_LEGACY
            if "du -sb" in cmd and "Images" in cmd:
                return "2100000000\t/sdcard/WhatsApp/Media/Images\n"
            if "du -sb" in cmd and "Video" in cmd:
                return "850000000\t/sdcard/WhatsApp/Media/Video\n"
            return None
        mock_run.side_effect = side_effect

        results = self.scanner.scan_device("abc", ["com.whatsapp"], 29)
        self.assertEqual(len(results), 1)
        data = results[0]
        self.assertEqual(data.package, "com.whatsapp")
        self.assertEqual(len(data.databases), 2)
        self.assertEqual(len(data.media), 2)
        self.assertGreater(data.totalBytes, 0)

    @patch("backend.scanner_service._run_adb_shell")
    def test_scan_only_installed_packages(self, mock_run):
        """Only scans packages that are in the provided list."""
        def side_effect(adb_path, serial, cmd):
            if "ls -la /sdcard/WhatsApp/Databases/" in cmd:
                return LS_DB_LEGACY
            return None
        mock_run.side_effect = side_effect

        results = self.scanner.scan_device("abc", ["com.whatsapp"], 29)
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0].package, "com.whatsapp")

    @patch("backend.scanner_service._run_adb_shell")
    def test_scan_returns_empty_for_no_data(self, mock_run):
        """Returns empty list when no WhatsApp data found."""
        mock_run.return_value = None
        results = self.scanner.scan_device("abc", ["com.whatsapp"], 29)
        self.assertEqual(len(results), 0)

    @patch("backend.scanner_service._run_adb_shell")
    def test_scoped_scan_uses_scoped_paths(self, mock_run):
        """Scoped scan (API 33) probes scoped storage paths."""
        def side_effect(adb_path, serial, cmd):
            if "Android/media/com.whatsapp/WhatsApp/Databases/" in cmd:
                return LS_DB_LEGACY
            if "du -sb" in cmd and "Android/media" in cmd and "Images" in cmd:
                return "1500000000\t/sdcard/Android/media/com.whatsapp/WhatsApp/Media/Images\n"
            if "du -sb" in cmd and "Android/media" in cmd and "Video" in cmd:
                return "600000000\t/sdcard/Android/media/com.whatsapp/WhatsApp/Media/Video\n"
            return None
        mock_run.side_effect = side_effect

        results = self.scanner.scan_device("abc", ["com.whatsapp"], 33)
        self.assertEqual(len(results), 1)
        data = results[0]
        self.assertEqual(len(data.databases), 2)
        self.assertEqual(len(data.media), 2)

    @patch("backend.scanner_service._run_adb_shell")
    def test_scoped_fallback_on_empty_media(self, mock_run):
        """Scoped falls back to /sdcard/Android/data/ when media path empty."""
        call_log: list[str] = []

        def side_effect(adb_path, serial, cmd):
            call_log.append(cmd)
            if "Android/media/com.whatsapp/WhatsApp/Databases/" in cmd:
                return None  # No Databases at scoped path
            if "du -sb" in cmd and "Android/media" in cmd:
                return ""  # No media at scoped path
            if "du -sb" in cmd and "Android/data/com.whatsapp" in cmd and "Images" in cmd:
                return "2100000000\t/sdcard/Android/data/com.whatsapp/files/Images\n"
            return None
        mock_run.side_effect = side_effect

        # Fallback should find media at data/ path
        results = self.scanner.scan_device("abc", ["com.whatsapp"], 33)
        self.assertEqual(len(results), 1)
        self.assertEqual(len(results[0].media), 1)
        self.assertIn("Android/data", call_log[-2])


if __name__ == "__main__":
    unittest.main()
