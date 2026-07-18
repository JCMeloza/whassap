"""Tests for main.py — request router and entry point (RED phase)."""
import json
import unittest
from unittest.mock import MagicMock, patch


class TestRequestRouter(unittest.TestCase):
    """Request routing and handler dispatch."""

    def setUp(self):
        from backend.main import RequestRouter

        self.mock_device = MagicMock()
        self.mock_adb = MagicMock()
        self.mock_scanner = MagicMock()
        self.mock_temp = MagicMock()
        self.mock_engine = MagicMock()
        self.router = RequestRouter(
            self.mock_adb, self.mock_device,
            self.mock_scanner, self.mock_temp, self.mock_engine,
        )

    def test_device_list_returns_devices(self):
        """device.list handler returns device list in result."""
        from backend.protocol import Request
        from backend.models import DeviceInfo

        self.mock_device.get_device_info.return_value = [
            DeviceInfo(serial="abc", model="Pixel", apiLevel=33,
                       packages=["com.whatsapp"]),
        ]

        req = Request(id="r1", method="device.list", params={})
        resp = self.router.handle(req)

        self.assertEqual(resp.id, "r1")
        self.assertIsNone(resp.error)
        self.assertEqual(len(resp.result["devices"]), 1)
        self.assertEqual(resp.result["devices"][0]["serial"], "abc")

    def test_unknown_method_returns_error(self):
        """Unknown method returns METHOD_NOT_FOUND error."""
        from backend.protocol import Request

        req = Request(id="r2", method="unknown.method", params={})
        resp = self.router.handle(req)

        self.assertEqual(resp.id, "r2")
        self.assertIsNone(resp.result)
        self.assertEqual(resp.error["code"], "METHOD_NOT_FOUND")

    def test_device_properties_returns_properties(self):
        """device.properties handler returns device properties."""
        from backend.protocol import Request

        self.mock_device.get_properties.return_value = {
            "apiLevel": 29, "model": "Pixel 5",
        }

        req = Request(id="r3", method="device.properties",
                       params={"serial": "abc"})
        resp = self.router.handle(req)

        self.assertEqual(resp.id, "r3")
        self.assertEqual(resp.result["apiLevel"], 29)
        self.mock_device.get_properties.assert_called_with("abc")

    def test_device_packages_returns_packages(self):
        """device.packages handler returns package list."""
        from backend.protocol import Request

        self.mock_device.detect_packages.return_value = [
            "com.whatsapp",
        ]

        req = Request(id="r4", method="device.packages",
                       params={"serial": "abc"})
        resp = self.router.handle(req)

        self.assertEqual(resp.id, "r4")
        self.assertIn("com.whatsapp", resp.result["packages"])

    def test_router_serializes_to_response_json(self):
        """Router response serializes to proper JSON."""
        from backend.protocol import Request

        self.mock_device.get_device_info.return_value = []

        req = Request(id="r5", method="device.list", params={})
        resp = self.router.handle(req)

        data = json.loads(resp.to_json())
        self.assertEqual(data["type"], "response")
        self.assertEqual(data["id"], "r5")
        self.assertIn("result", data)


class TestParseRequest(unittest.TestCase):
    """JSON line parsing into Request objects."""

    def test_parse_valid_request(self):
        """Valid JSON parses into Request."""
        from backend.main import _parse_request
        from backend.protocol import Request

        line = '{"type":"request","id":"r1","method":"device.list","params":{}}'
        req = _parse_request(line)
        self.assertIsNotNone(req)
        self.assertIsInstance(req, Request)
        self.assertEqual(req.id, "r1")
        self.assertEqual(req.method, "device.list")

    def test_parse_invalid_json(self):
        """Invalid JSON returns None."""
        from backend.main import _parse_request

        req = _parse_request("not json")
        self.assertIsNone(req)

    def test_parse_missing_fields(self):
        """JSON missing required fields returns None."""
        from backend.main import _parse_request

        req = _parse_request('{"type":"request"}')
        self.assertIsNone(req)


if __name__ == "__main__":
    unittest.main()
