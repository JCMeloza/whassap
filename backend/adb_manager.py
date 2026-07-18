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
        self.source: str = "bundled"
        self._detect_version()
        self.source = "system" if self._is_system_adb() else "bundled"

    def _is_system_adb(self) -> bool:
        """Check if current path is a system ADB (not bundled)."""
        return "backend/bin" not in self.adb_path

    @staticmethod
    def _detect_system_version(path: str) -> str | None:
        """Run `adb version` for a given path and return parsed version."""
        try:
            result = subprocess.run(
                [path, "version"],
                capture_output=True, text=True, timeout=5,
            )
            if result.returncode == 0:
                return _parse_adb_version(result.stdout)
        except (subprocess.SubprocessError, FileNotFoundError, OSError):
            pass
        return None

    def _find_adb(self) -> str:
        """Resolve ADB binary: system PATH first (if ≥ v31), bundled fallback."""
        system_adb = shutil.which("adb")
        if system_adb:
            ver = self._detect_system_version(system_adb)
            if ver:
                try:
                    major = int(ver.split(".")[0])
                    if major >= 31:
                        return system_adb
                except (ValueError, IndexError):
                    pass
        return _get_bundled_adb_path()

    def _detect_version(self) -> None:
        """Run `adb version` on the resolved path and parse version."""
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
