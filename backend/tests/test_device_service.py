"""Tests for device_service.py — device detection (RED phase)."""
import unittest
from unittest.mock import patch, MagicMock, call


ADB_DEVICES_SINGLE = """List of devices attached
abc123    device product:walleye model:Pixel_2 device:walleye transport_id:1
"""

ADB_DEVICES_OUTPUT = """List of devices attached
abc123    device product:walleye model:Pixel_2 device:walleye transport_id:1
def456    device product:blueline model:Pixel_3 device:blueline transport_id:2
"""

ADB_DEVICES_EMPTY = """List of devices attached

"""

ADB_DEVICES_UNAUTHORIZED = """List of devices attached
abc123    unauthorized
"""

PM_LIST_OUTPUT = """package:/data/app/com.whatsapp-xyz/base.apk=com.whatsapp
package:/data/app/com.whatsapp.w4b-xyz/base.apk=com.whatsapp.w4b
"""

PM_LIST_WA_ONLY = """package:/data/app/com.whatsapp-xyz/base.apk=com.whatsapp
"""

PM_LIST_EMPTY = """"""


class TestDeviceEnumeration(unittest.TestCase):
    """Device list parsing from `adb devices -l`."""

    @patch("subprocess.run")
    def test_list_devices_multiple(self, mock_run):
        """Parses multiple authorized devices correctly."""
        mock_run.return_value = MagicMock(
            returncode=0, stdout=ADB_DEVICES_OUTPUT, stderr=""
        )
        from backend.device_service import DeviceService

        svc = DeviceService(MagicMock(adb_path="/usr/bin/adb"))
        devices = svc.list_devices()

        self.assertEqual(len(devices), 2)
        self.assertEqual(devices[0]["serial"], "abc123")
        self.assertEqual(devices[0]["model"], "Pixel_2")
        self.assertEqual(devices[1]["serial"], "def456")

    @patch("subprocess.run")
    def test_list_devices_unauthorized_excluded(self, mock_run):
        """Unauthorized devices are excluded."""
        mock_run.return_value = MagicMock(
            returncode=0, stdout=ADB_DEVICES_UNAUTHORIZED, stderr=""
        )
        from backend.device_service import DeviceService

        svc = DeviceService(MagicMock(adb_path="/usr/bin/adb"))
        devices = svc.list_devices()

        self.assertEqual(len(devices), 0)

    @patch("subprocess.run")
    def test_list_devices_empty(self, mock_run):
        """Returns empty list when no devices connected."""
        mock_run.return_value = MagicMock(
            returncode=0, stdout=ADB_DEVICES_EMPTY, stderr=""
        )
        from backend.device_service import DeviceService

        svc = DeviceService(MagicMock(adb_path="/usr/bin/adb"))
        devices = svc.list_devices()

        self.assertEqual(len(devices), 0)


class TestDeviceProperties(unittest.TestCase):
    """Device property retrieval via getprop."""

    @patch("subprocess.run")
    def test_get_properties(self, mock_run):
        """Returns correct model and API level from getprop."""
        mock_run.side_effect = [
            MagicMock(returncode=0, stdout="33\n", stderr=""),
            MagicMock(returncode=0, stdout="Pixel 8\n", stderr=""),
        ]
        from backend.device_service import DeviceService

        svc = DeviceService(MagicMock(adb_path="/usr/bin/adb"))
        props = svc.get_properties("abc123")

        self.assertEqual(props["apiLevel"], 33)
        self.assertEqual(props["model"], "Pixel 8")


class TestPackageDetection(unittest.TestCase):
    """WhatsApp package detection via pm list packages."""

    @patch("subprocess.run")
    def test_detect_both_packages(self, mock_run):
        """Detects both WhatsApp and WhatsApp Business."""
        mock_run.return_value = MagicMock(
            returncode=0, stdout=PM_LIST_OUTPUT, stderr=""
        )
        from backend.device_service import DeviceService

        svc = DeviceService(MagicMock(adb_path="/usr/bin/adb"))
        packages = svc.detect_packages("abc123")

        self.assertIn("com.whatsapp", packages)
        self.assertIn("com.whatsapp.w4b", packages)

    @patch("subprocess.run")
    def test_detect_whatsapp_only(self, mock_run):
        """Detects only WhatsApp when Business not installed."""
        mock_run.return_value = MagicMock(
            returncode=0, stdout=PM_LIST_WA_ONLY, stderr=""
        )
        from backend.device_service import DeviceService

        svc = DeviceService(MagicMock(adb_path="/usr/bin/adb"))
        packages = svc.detect_packages("abc123")

        self.assertIn("com.whatsapp", packages)
        self.assertNotIn("com.whatsapp.w4b", packages)

    @patch("subprocess.run")
    def test_detect_no_packages(self, mock_run):
        """Returns empty list when no WhatsApp installed."""
        mock_run.return_value = MagicMock(
            returncode=0, stdout=PM_LIST_EMPTY, stderr=""
        )
        from backend.device_service import DeviceService

        svc = DeviceService(MagicMock(adb_path="/usr/bin/adb"))
        packages = svc.detect_packages("abc123")

        self.assertEqual(len(packages), 0)


class TestGetDeviceInfo(unittest.TestCase):
    """Full device info aggregation."""

    @patch("subprocess.run")
    def test_get_device_info(self, mock_run):
        """get_device_info returns complete DeviceInfo."""
        mock_run.side_effect = [
            # 0: list_devices -> adb devices -l
            MagicMock(returncode=0, stdout=ADB_DEVICES_SINGLE, stderr=""),
            # 1: get_properties -> getprop sdk
            MagicMock(returncode=0, stdout="33\n", stderr=""),
            # 2: get_properties -> getprop model
            MagicMock(returncode=0, stdout="Pixel 8\n", stderr=""),
            # 3: detect_packages -> pm list packages
            MagicMock(returncode=0, stdout=PM_LIST_WA_ONLY, stderr=""),
        ]
        from backend.device_service import DeviceService
        from backend.models import DeviceInfo

        svc = DeviceService(MagicMock(adb_path="/usr/bin/adb"))
        devices = svc.get_device_info()

        self.assertEqual(len(devices), 1)
        self.assertIsInstance(devices[0], DeviceInfo)
        self.assertEqual(devices[0].serial, "abc123")
        self.assertEqual(devices[0].apiLevel, 33)
        self.assertEqual(devices[0].classification, "scoped")
        self.assertIn("com.whatsapp", devices[0].packages)


if __name__ == "__main__":
    unittest.main()
