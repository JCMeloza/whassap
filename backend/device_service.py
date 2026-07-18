"""Device service for WhatsApp Transfer Tool.

Handles ADB device enumeration, property retrieval, and
WhatsApp package detection on connected Android devices.
"""

import subprocess
import re
from backend.models import DeviceInfo


def _parse_device_list(adb_output: str) -> list[dict]:
    """Parse `adb devices -l` output into device dicts.

    Returns list of dicts with serial, model, transport_id for
    authorized (device state) devices only.
    """
    devices: list[dict] = []
    for line in adb_output.splitlines():
        line = line.strip()
        if not line or line.startswith("List of devices"):
            continue
        parts = line.split()
        if len(parts) < 2:
            continue
        serial = parts[0]
        state = parts[1]
        if state != "device":
            continue
        entry: dict = {"serial": serial}
        for pair in parts[2:]:
            if ":" not in pair:
                continue
            key, value = pair.split(":", 1)
            if key in ("model", "product", "device", "transport_id"):
                entry[key] = value
        devices.append(entry)
    return devices


class DeviceService:
    """Service for ADB device detection and info."""

    def __init__(self, adb_provider):
        self._adb = adb_provider

    def list_devices(self) -> list[dict]:
        """List authorized devices via `adb devices -l`."""
        result = subprocess.run(
            [self._adb.adb_path, "devices", "-l"],
            capture_output=True, text=True, timeout=10,
        )
        if result.returncode != 0:
            return []
        return _parse_device_list(result.stdout)

    def get_properties(self, serial: str) -> dict:
        """Get API level and model for a device via getprop."""
        sdk = subprocess.run(
            [self._adb.adb_path, "-s", serial, "shell",
             "getprop", "ro.build.version.sdk"],
            capture_output=True, text=True, timeout=10,
        )
        model = subprocess.run(
            [self._adb.adb_path, "-s", serial, "shell",
             "getprop", "ro.product.model"],
            capture_output=True, text=True, timeout=10,
        )
        api_level = int(sdk.stdout.strip()) if sdk.returncode == 0 and sdk.stdout.strip().isdigit() else 0
        return {
            "apiLevel": api_level,
            "model": model.stdout.strip() if model.returncode == 0 else "Unknown",
        }

    def detect_packages(self, serial: str) -> list[str]:
        """Detect WhatsApp packages installed on a device."""
        result = subprocess.run(
            [self._adb.adb_path, "-s", serial, "shell",
             "pm", "list", "packages", "-f"],
            capture_output=True, text=True, timeout=10,
        )
        if result.returncode != 0:
            return []
        packages: list[str] = []
        for line in result.stdout.splitlines():
            match = re.search(r"=(com\.whatsapp(?:\..+)?)\s*$", line)
            if match:
                pkg = match.group(1)
                if pkg in ("com.whatsapp", "com.whatsapp.w4b"):
                    packages.append(pkg)
        return packages

    def get_device_info(self) -> list[DeviceInfo]:
        """Get full DeviceInfo for all authorized devices."""
        device_list = self.list_devices()
        result: list[DeviceInfo] = []
        for dev in device_list:
            serial = dev["serial"]
            props = self.get_properties(serial)
            packages = self.detect_packages(serial)
            result.append(DeviceInfo(
                serial=serial,
                model=props["model"],
                apiLevel=props["apiLevel"],
                packages=packages,
            ))
        return result
