"""ADB binary management for WhatsApp Transfer Tool.

Handles system ADB detection, bundled fallback, version checking,
and server lifecycle (start-server / kill-server).
"""

import os
import re
import shutil
import subprocess
import platform
from pathlib import Path


def _get_bundled_adb_path() -> str:
    """Return path to bundled ADB binary for the current platform."""
    base = Path(__file__).resolve().parent / "bin"
    if platform.system() == "Windows":
        return str(base / "windows" / "adb.exe")
    return str(base / "linux" / "adb")


def _parse_adb_version(version_output: str) -> str | None:
    """Extract version string from `adb version` output.

    Expected format: "Version 34.0.5-..."
    Returns the version segment (e.g. "34.0.5") or None.
    """
    match = re.search(r"Version\s+(\d+\.\d+\.\d+)", version_output)
    return match.group(1) if match else None


class AdbManager:
    """Manages ADB binary selection and lifecycle."""

    def __init__(self):
        self.adb_path: str = self._find_adb()
        self.version: str | None = None
        self.source: str = "system" if self._is_system_adb() else "bundled"
        self._detect_version()

    def _is_system_adb(self) -> bool:
        """Check if current path is a system ADB (not bundled)."""
        return "backend/bin" not in self.adb_path

    def _find_adb(self) -> str:
        """Resolve ADB binary: system PATH first, bundled fallback."""
        system_adb = shutil.which("adb")
        if system_adb:
            return system_adb
        return _get_bundled_adb_path()

    def _detect_version(self) -> None:
        """Run `adb version` and parse the version string."""
        try:
            result = subprocess.run(
                [self.adb_path, "version"],
                capture_output=True, text=True, timeout=5,
            )
            if result.returncode == 0:
                self.version = _parse_adb_version(result.stdout)
        except (subprocess.SubprocessError, FileNotFoundError, OSError):
            self.version = None

    def start_server(self) -> None:
        """Start the ADB server."""
        subprocess.run(
            [self.adb_path, "start-server"],
            capture_output=True, timeout=10,
        )

    def kill_server(self) -> None:
        """Kill the ADB server."""
        subprocess.run(
            [self.adb_path, "kill-server"],
            capture_output=True, timeout=10,
        )
