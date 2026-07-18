"""Tests for adb_manager.py — ADB binary management (RED phase)."""
import unittest
from unittest.mock import patch, MagicMock


class TestAdbResolution(unittest.TestCase):
    """ADB binary finding and version checking."""

    @patch("shutil.which")
    def test_system_adb_found(self, mock_which):
        """Returns system ADB path when found in PATH."""
        mock_which.return_value = "/usr/bin/adb"
        from backend.adb_manager import AdbManager

        mgr = AdbManager()
        self.assertEqual(mgr._find_adb(), "/usr/bin/adb")

    @patch("shutil.which")
    def test_system_adb_not_found_falls_to_bundled(self, mock_which):
        """Returns bundled ADB when not in PATH."""
        mock_which.return_value = None
        from backend.adb_manager import AdbManager

        mgr = AdbManager()
        path = mgr._find_adb()
        self.assertIsNotNone(path)
        self.assertIn("backend/bin", path)

    @patch("shutil.which")
    def test_bundled_path_contains_adb(self, mock_which):
        """Bundled path ends with 'adb' executable name."""
        mock_which.return_value = None
        from backend.adb_manager import AdbManager

        mgr = AdbManager()
        path = mgr._find_adb()
        self.assertTrue(path.endswith("adb") or path.endswith("adb.exe"))


class TestAdbVersionParsing(unittest.TestCase):
    """ADB version string parsing."""

    def test_parse_version_34(self):
        """Parses ADB 34 version string correctly."""
        from backend.adb_manager import _parse_adb_version

        output = "Android Debug Bridge version 1.0.41\nVersion 34.0.5-..."
        version = _parse_adb_version(output)
        self.assertIsNotNone(version)
        major = int(version.split(".")[0])
        self.assertGreaterEqual(major, 34)

    def test_parse_version_old_format(self):
        """Parses older ADB version format."""
        from backend.adb_manager import _parse_adb_version

        output = "Android Debug Bridge version 1.0.39\nVersion 29.0.1-..."
        version = _parse_adb_version(output)
        self.assertIsNotNone(version)
        major = int(version.split(".")[0])
        self.assertLess(major, 31)

    def test_parse_version_unexpected_format(self):
        """Returns None for unparseable version output."""
        from backend.adb_manager import _parse_adb_version

        version = _parse_adb_version("unexpected output")
        self.assertIsNone(version)


class TestAdbServerLifecycle(unittest.TestCase):
    """ADB server start/kill."""

    @patch("subprocess.run")
    @patch("shutil.which")
    def test_start_server(self, mock_which, mock_run):
        """start_server calls adb start-server."""
        mock_which.return_value = "/usr/bin/adb"
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout="Android Debug Bridge version 1.0.41\nVersion 34.0.5\n",
        )
        from backend.adb_manager import AdbManager

        mgr = AdbManager()
        mgr.start_server()

        # 2 calls: one from __init__ (version detect), one from start_server
        self.assertEqual(mock_run.call_count, 2)
        last_call = mock_run.call_args_list[-1]
        args = last_call[0][0]
        self.assertIn("start-server", args)

    @patch("subprocess.run")
    @patch("shutil.which")
    def test_kill_server(self, mock_which, mock_run):
        """kill_server calls adb kill-server."""
        mock_which.return_value = "/usr/bin/adb"
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout="Android Debug Bridge version 1.0.41\nVersion 34.0.5\n",
        )
        from backend.adb_manager import AdbManager

        mgr = AdbManager()
        mgr.kill_server()

        self.assertEqual(mock_run.call_count, 2)
        last_call = mock_run.call_args_list[-1]
        args = last_call[0][0]
        self.assertIn("kill-server", args)


class TestAdbInfo(unittest.TestCase):
    """ADB info reporting."""

    @patch("subprocess.run")
    @patch("shutil.which")
    def test_adb_info_attributes(self, mock_which, mock_run):
        """AdbManager exposes path, version, source after init."""
        mock_which.return_value = "/usr/bin/adb"
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout="Android Debug Bridge version 1.0.41\nVersion 34.0.5-...\n",
        )
        from backend.adb_manager import AdbManager

        mgr = AdbManager()
        self.assertEqual(mgr.adb_path, "/usr/bin/adb")
        self.assertIsNotNone(mgr.version)
        self.assertEqual(mgr.source, "system")


if __name__ == "__main__":
    unittest.main()
