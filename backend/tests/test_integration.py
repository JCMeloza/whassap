"""Integration tests for WhatsApp Transfer Tool Python backend.

Tests the backend subprocess spawn, NDJSON protocol round-trip,
temp directory cleanup, and real ADB device interaction.

Usage:
    python3 -m unittest backend/tests/test_integration.py -v
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


# ── Project root detection ────────────────────────────────────────

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent


# ── ADB availability check ────────────────────────────────────────

def _has_real_adb() -> bool:
    """Check if ADB is on PATH and has at least one connected device."""
    try:
        result = subprocess.run(
            ["adb", "devices"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if result.returncode != 0:
            return False
        lines = [l.strip() for l in result.stdout.splitlines() if l.strip()]
        # First line is "List of devices attached", subsequent lines
        # with "device" state indicate connected devices
        for line in lines[1:]:
            parts = line.split()
            if len(parts) >= 2 and parts[1] == "device":
                return True
        return False
    except (subprocess.SubprocessError, FileNotFoundError):
        return False


no_real_adb = not _has_real_adb()


# ── Integration Tests ─────────────────────────────────────────────

class TestBackendSpawn(unittest.TestCase):
    """Tests that the backend subprocess starts and communicates via NDJSON."""

    def setUp(self):
        self.project_root = PROJECT_ROOT
        self.proc: subprocess.Popen | None = None

    def tearDown(self):
        if self.proc is not None:
            try:
                if self.proc.stdin and not self.proc.stdin.closed:
                    self.proc.stdin.close()
            except Exception:
                pass
            try:
                self.proc.terminate()
                self.proc.wait(timeout=5)
            except Exception:
                try:
                    self.proc.kill()
                    self.proc.wait(timeout=2)
                except Exception:
                    pass
            for pipe in (self.proc.stdout, self.proc.stderr):
                try:
                    if pipe and not pipe.closed:
                        pipe.close()
                except Exception:
                    pass

    def _start_backend(self) -> subprocess.Popen:
        """Start the backend as a subprocess."""
        proc = subprocess.Popen(
            [sys.executable, "-m", "backend.main"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,          # Line-buffered
            cwd=str(self.project_root),
        )
        self.proc = proc
        return proc

    def _read_line(self, timeout: float = 10.0) -> str:
        """Read one line from stdout with a timeout."""
        import select
        import errno

        fd = self.proc.stdout.fileno()
        end_time = __import__("time").time() + timeout

        while __import__("time").time() < end_time:
            readable, _, exceptional = select.select(
                [fd], [], [fd], max(0.1, end_time - __import__("time").time())
            )
            if exceptional:
                stderr = self._read_stderr()
                raise RuntimeError(
                    f"Process exceptional condition. stderr: {stderr}"
                )
            if readable:
                line = self.proc.stdout.readline()
                if line == "":
                    stderr = self._read_stderr()
                    raise RuntimeError(
                        f"Process closed stdout. stderr: {stderr}"
                    )
                return line.strip()
        stderr = self._read_stderr()
        raise TimeoutError(
            f"Timed out after {timeout}s waiting for stdout line. "
            f"stderr: {stderr}"
        )

    def _read_stderr(self) -> str:
        """Read all available stderr output."""
        import select
        fd = self.proc.stderr.fileno()
        data = ""
        readable, _, _ = select.select([fd], [], [], 0.5)
        while readable:
            try:
                chunk = os.read(fd, 4096)
                if not chunk:
                    break
                data += chunk.decode("utf-8", errors="replace")
            except OSError:
                break
            readable, _, _ = select.select([fd], [], [], 0.1)
        return data

    def _send_request(self, request: dict) -> None:
        """Send a JSON request line to the backend."""
        line = json.dumps(request, separators=(",", ":"))
        self.proc.stdin.write(line + "\n")
        self.proc.stdin.flush()

    def test_backend_spawns_and_emits_startup_event(self):
        """Start backend and verify the adb_info startup event."""
        proc = self._start_backend()

        first_line = self._read_line()
        event = json.loads(first_line)

        self.assertEqual(event.get("type"), "event")
        self.assertEqual(event.get("event"), "adb_info")
        self.assertIn("data", event)
        self.assertIn("path", event["data"])
        self.assertIn("version", event["data"])
        self.assertIn("source", event["data"])

    def test_device_list_returns_response(self):
        """Send device.list request and get a valid JSON response."""
        proc = self._start_backend()

        # Consume startup event
        self._read_line()

        # Send device.list request
        self._send_request({
            "type": "request",
            "id": "integ-test-device-list",
            "method": "device.list",
            "params": {},
        })

        # Read response
        response_line = self._read_line()
        response = json.loads(response_line)

        self.assertEqual(response.get("type"), "response")
        self.assertEqual(response.get("id"), "integ-test-device-list")
        # Either a result (ADB available) or an error (no ADB)
        if "result" in response:
            self.assertIn("devices", response["result"])
        elif "error" in response:
            self.assertEqual(response["error"]["code"], "INTERNAL_ERROR")

    def test_invalid_request_returns_error(self):
        """Send invalid JSON and verify error response."""
        proc = self._start_backend()

        # Consume startup event
        self._read_line()

        # Send invalid JSON
        self.proc.stdin.write("not valid json\n")
        self.proc.stdin.flush()

        # Read response
        response_line = self._read_line()
        response = json.loads(response_line)

        self.assertEqual(response.get("type"), "response")
        self.assertIn("error", response)
        self.assertEqual(response["error"]["code"], "INVALID_REQUEST")

    def test_unknown_method_returns_error(self):
        """Send request with unknown method and verify METHOD_NOT_FOUND."""
        proc = self._start_backend()

        # Consume startup event
        self._read_line()

        self._send_request({
            "type": "request",
            "id": "integ-test-unknown",
            "method": "nonexistent.method",
            "params": {},
        })

        response_line = self._read_line()
        response = json.loads(response_line)

        self.assertEqual(response.get("type"), "response")
        self.assertIn("error", response)
        self.assertEqual(response["error"]["code"], "METHOD_NOT_FOUND")

    def test_backend_cleans_up_on_termination(self):
        """Backend process terminates cleanly when stdin is closed."""
        proc = self._start_backend()

        # Consume startup event
        self._read_line()

        # Close stdin and wait for process to exit
        proc.stdin.close()
        proc.wait(timeout=5)

        self.assertEqual(proc.returncode, 0)

    @unittest.skipIf(no_real_adb, "Requires ADB-connected device")
    def test_real_adb_device_list(self):
        """Full integration test with real ADB: device list returns data."""
        proc = self._start_backend()

        # Consume startup event
        startup = self._read_line()
        event = json.loads(startup)
        # With real ADB, the event should show a real version
        self.assertNotEqual(event["data"]["version"], "unknown")

        # Send device.list
        self._send_request({
            "type": "request",
            "id": "integ-real-devices",
            "method": "device.list",
            "params": {},
        })

        response_line = self._read_line()
        response = json.loads(response_line)

        self.assertEqual(response.get("type"), "response")
        self.assertIn("result", response)
        self.assertIn("devices", response["result"])
        # There should be at least one device
        self.assertGreater(len(response["result"]["devices"]), 0)

    @unittest.skipIf(no_real_adb, "Requires ADB-connected device")
    def test_real_adb_device_properties(self):
        """Get properties of the first connected device."""
        proc = self._start_backend()

        # Consume startup event
        self._read_line()

        # List devices first
        self._send_request({
            "type": "request",
            "id": "integ-list",
            "method": "device.list",
            "params": {},
        })
        list_resp = json.loads(self._read_line())
        if "error" in list_resp:
            self.skipTest("device.list failed")

        serial = list_resp["result"]["devices"][0]["serial"]

        # Get properties
        self._send_request({
            "type": "request",
            "id": "integ-props",
            "method": "device.properties",
            "params": {"serial": serial},
        })
        props_resp = json.loads(self._read_line())

        self.assertEqual(props_resp.get("type"), "response")
        self.assertIn("result", props_resp)
        self.assertIn("apiLevel", props_resp["result"])
        self.assertIn("model", props_resp["result"])


class TestTempDirCleanup(unittest.TestCase):
    """Tests for temp directory cleanup functionality."""

    def test_cleanup_orphans_removes_stale_dirs(self):
        """Static cleanup_orphans removes matching temp dirs."""
        from backend.temp_storage import TempStorage

        # Create an orphan temp dir
        orphan_dir = Path(tempfile.gettempdir()) / "whatsapp-transfer-test-orphan"
        orphan_dir.mkdir(parents=True, exist_ok=True)
        (orphan_dir / "test.txt").write_text("test data")

        self.assertTrue(orphan_dir.exists())

        try:
            count = TempStorage.cleanup_orphans()
            # The orphan dir should be gone
            self.assertFalse(orphan_dir.exists())
            self.assertGreaterEqual(count, 1)
        finally:
            # Clean up in case test failed
            if orphan_dir.exists():
                shutil.rmtree(orphan_dir, ignore_errors=True)

    def test_cleanup_orphans_no_side_effects(self):
        """cleanup_orphans does not remove unrelated temp files."""
        from backend.temp_storage import TempStorage

        # Create a non-matching temp dir
        safe_dir = Path(tempfile.gettempdir()) / "unrelated-test-dir"
        safe_dir.mkdir(parents=True, exist_ok=True)
        (safe_dir / "test.txt").write_text("test")

        try:
            TempStorage.cleanup_orphans()
            # Unrelated dir should still exist
            self.assertTrue(safe_dir.exists())
        finally:
            if safe_dir.exists():
                shutil.rmtree(safe_dir, ignore_errors=True)

    def test_orphan_cleanup_on_backend_startup(self):
        """Starting the backend cleans up orphaned temp dirs."""
        from backend.temp_storage import TempStorage

        # Create an orphan dir
        orphan_dir = Path(tempfile.gettempdir()) / "whatsapp-transfer-startup-test"
        orphan_dir.mkdir(parents=True, exist_ok=True)
        (orphan_dir / "data.bin").write_text("fake transfer data")

        self.assertTrue(orphan_dir.exists())

        proc = None
        try:
            proc = subprocess.Popen(
                [sys.executable, "-m", "backend.main"],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                bufsize=1,
                cwd=str(PROJECT_ROOT),
            )

            # Wait for startup event (backend calls cleanup_orphans during init)
            import select
            fd = proc.stdout.fileno()
            readable, _, _ = select.select([fd], [], [], 10)
            if readable:
                proc.stdout.readline()  # consume adb_info event

            # Orphan dir should be cleaned up
            self.assertFalse(orphan_dir.exists(), 
                             "Orphan temp dir should be cleaned on startup")
        finally:
            if proc is not None:
                try:
                    proc.terminate()
                    proc.wait(timeout=5)
                except Exception:
                    proc.kill()
            if orphan_dir.exists():
                shutil.rmtree(orphan_dir, ignore_errors=True)


if __name__ == "__main__":
    unittest.main()
