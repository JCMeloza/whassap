"""Tests for temp_storage.py — temp directory management (RED phase)."""
import os
import tempfile
import unittest
from unittest.mock import patch, MagicMock
from pathlib import Path


class TestTempStorage(unittest.TestCase):
    """TempStorage creation, space checks, and cleanup."""

    def setUp(self):
        from backend.temp_storage import TempStorage

        self.storage = TempStorage()

    def tearDown(self):
        if self.storage.temp_dir and self.storage.temp_dir.exists():
            import shutil
            shutil.rmtree(self.storage.temp_dir, ignore_errors=True)

    def test_create_creates_unique_dir(self):
        """create() creates a whatsapp-transfer-* dir under tempdir."""
        tid = "test-123"
        path = self.storage.create(tid)
        self.assertTrue(path.exists())
        self.assertTrue(path.is_dir())
        self.assertIn("whatsapp-transfer-test-123", str(path))

    def test_create_sets_0700_permissions(self):
        """Created directory has 0o700 permissions."""
        path = self.storage.create("perm-test")
        mode = os.stat(path).st_mode & 0o777
        self.assertEqual(mode, 0o700)

    def test_ensure_package_dirs_creates_subdirs(self):
        """Creates source/<pkg>/Databases/ and Media/ subdirectories."""
        self.storage.create("pkg-dirs")
        self.storage.ensure_package_dirs(["com.whatsapp", "com.whatsapp.w4b"])

        src = self.storage.temp_dir / "source"
        self.assertTrue((src / "com.whatsapp" / "Databases").exists())
        self.assertTrue((src / "com.whatsapp" / "Media").exists())
        self.assertTrue((src / "com.whatsapp.w4b" / "Databases").exists())
        self.assertTrue((src / "com.whatsapp.w4b" / "Media").exists())

    def test_check_space_sufficient(self):
        """check_space returns True with enough free space."""
        self.storage.create("space-ok")
        ok, msg = self.storage.check_space(1)  # Need 1 byte × 1.1 = ~1 byte
        self.assertTrue(ok)
        self.assertIn("Sufficient", msg)

    def test_check_space_insufficient(self):
        """check_space returns False when 110% of required exceeds free."""
        self.storage.create("space-fail")
        # Request astronomically large requirement
        ok, msg = self.storage.check_space(10 ** 30)
        self.assertFalse(ok)
        self.assertIn("Insufficient", msg)

    def test_cleanup_removes_temp_dir(self):
        """cleanup() deletes the temp directory."""
        self.storage.create("clean-test")
        path = self.storage.temp_dir
        self.assertTrue(path.exists())
        self.storage.cleanup()
        self.assertFalse(path.exists())
        self.assertIsNone(self.storage.temp_dir)

    @patch("pathlib.Path.glob")
    def test_cleanup_orphans_removes_matching_dirs(self, mock_glob):
        """cleanup_orphans() removes orphan whatsapp-transfer-* dirs."""
        mock_glob.return_value = []
        from backend.temp_storage import TempStorage
        count = TempStorage.cleanup_orphans()
        self.assertEqual(count, 0)


class TestTempStorageNoDir(unittest.TestCase):
    """TempStorage operations without creating a directory."""

    def test_check_space_fails_without_temp_dir(self):
        """check_space returns False when temp dir not created."""
        from backend.temp_storage import TempStorage

        storage = TempStorage()
        ok, msg = storage.check_space(100)
        self.assertFalse(ok)
        self.assertIn("not created", msg)


if __name__ == "__main__":
    unittest.main()
