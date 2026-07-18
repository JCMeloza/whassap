"""Tests for protocol.py — NDJSON message types (RED phase)."""
import json
import unittest
from uuid import uuid4


class TestRequest(unittest.TestCase):
    """Request message serialization."""

    def test_request_to_json_round_trip(self):
        """Request serializes to expected JSON and back."""
        from backend.protocol import Request

        req = Request(id="abc-123", method="device.list", params={})
        data = json.loads(req.to_json())

        self.assertEqual(data["type"], "request")
        self.assertEqual(data["id"], "abc-123")
        self.assertEqual(data["method"], "device.list")
        self.assertEqual(data["params"], {})

    def test_request_with_params(self):
        """Request with params serializes correctly."""
        from backend.protocol import Request

        req = Request(
            id="xyz-789",
            method="device.properties",
            params={"serial": "abc123"},
        )
        data = json.loads(req.to_json())

        self.assertEqual(data["method"], "device.properties")
        self.assertEqual(data["params"]["serial"], "abc123")


class TestResponse(unittest.TestCase):
    """Response message serialization."""

    def test_response_with_result(self):
        """Response with result field serializes correctly."""
        from backend.protocol import Response

        resp = Response(id="abc-123", result={"devices": []})
        data = json.loads(resp.to_json())

        self.assertEqual(data["type"], "response")
        self.assertEqual(data["id"], "abc-123")
        self.assertEqual(data["result"]["devices"], [])

    def test_response_with_error(self):
        """Response with error field omits result."""
        from backend.protocol import Response

        resp = Response(
            id="abc-123",
            error={"code": "DEVICE_NOT_FOUND", "message": "No device"},
        )
        data = json.loads(resp.to_json())

        self.assertEqual(data["type"], "response")
        self.assertIn("error", data)
        self.assertNotIn("result", data)
        self.assertEqual(data["error"]["code"], "DEVICE_NOT_FOUND")


class TestProgressEvent(unittest.TestCase):
    """Progress event serialization."""

    def test_progress_event(self):
        """ProgressEvent serializes all fields."""
        from backend.protocol import ProgressEvent

        evt = ProgressEvent(
            transferId="t1",
            phase="pull",
            package="com.whatsapp",
            item="Databases/msgstore.db.crypt14",
            bytesTransferred=1000,
            bytesTotal=5000,
            percentage=20.0,
            transferRateBps=12_000_000,
            etaSeconds=320,
        )
        data = json.loads(evt.to_json())

        self.assertEqual(data["type"], "progress")
        self.assertEqual(data["phase"], "pull")
        self.assertEqual(data["percentage"], 20.0)
        self.assertEqual(data["etaSeconds"], 320)


class TestPhaseChangeEvent(unittest.TestCase):
    """Phase change event serialization."""

    def test_phase_change(self):
        """PhaseChangeEvent serializes from/to phases."""
        from backend.protocol import PhaseChangeEvent

        evt = PhaseChangeEvent(transferId="t1", from_="pull", to="push")
        data = json.loads(evt.to_json())

        self.assertEqual(data["type"], "phase_change")
        self.assertEqual(data["from"], "pull")
        self.assertEqual(data["to"], "push")


class TestEventMessages(unittest.TestCase):
    """Event messages (ADB info, driver issue) serialization."""

    def test_adb_info_event(self):
        """AdbInfoEvent serializes with source, version, path."""
        from backend.protocol import AdbInfoEvent

        evt = AdbInfoEvent(data={
            "path": "/usr/bin/adb",
            "version": "34.0.5",
            "source": "system",
        })
        data = json.loads(evt.to_json())

        self.assertEqual(data["type"], "event")
        self.assertEqual(data["event"], "adb_info")
        self.assertEqual(data["data"]["version"], "34.0.5")

    def test_driver_issue_event(self):
        """DriverIssueEvent serializes with message."""
        from backend.protocol import DriverIssueEvent

        evt = DriverIssueEvent(data={
            "message": "Android device detected but ADB interface missing",
        })
        data = json.loads(evt.to_json())

        self.assertEqual(data["type"], "event")
        self.assertEqual(data["event"], "driver_issue")
        self.assertIn("message", data["data"])


if __name__ == "__main__":
    unittest.main()
