"""Temp storage management for WhatsApp Transfer Tool.

Manages unique temporary directories per transfer session, space
validation (110% rule), and cleanup on success/failure/cancel.
"""

import os
import shutil
import tempfile
from pathlib import Path
from uuid import uuid4


class TempStorage:
    """Manages a temporary directory for a single transfer."""

    def __init__(self):
        self._temp_dir: Path | None = None

    @property
    def temp_dir(self) -> Path | None:
        """Get the current temp directory path."""
        return self._temp_dir

    def create(self, transfer_id: str | None = None) -> Path:
        """Create a unique temp directory for a transfer.

        Creates parent dir and subdirectory structure under OS temp dir.
        Sets 0o700 permissions (owner-only access).
        """
        tid = transfer_id or str(uuid4())
        base = Path(tempfile.gettempdir())
        self._temp_dir = base / f"whatsapp-transfer-{tid}"
        self._temp_dir.mkdir(parents=True, exist_ok=True)
        self._temp_dir.chmod(0o700)
        (self._temp_dir / "source").mkdir(exist_ok=True)
        return self._temp_dir

    def ensure_package_dirs(self, packages: list[str]) -> None:
        """Create package-level subdirectories under source/."""
        if self._temp_dir is None:
            raise RuntimeError("Temp directory not created")
        for pkg in packages:
            pkg_dir = self._temp_dir / "source" / pkg
            (pkg_dir / "Databases").mkdir(parents=True, exist_ok=True)
            (pkg_dir / "Media").mkdir(parents=True, exist_ok=True)

    def check_space(self, required_bytes: int) -> tuple[bool, str]:
        """Check if temp dir has enough free space (110% headroom).

        Returns (ok, message). Calculates needed = required_bytes * 1.1.
        """
        if self._temp_dir is None:
            return False, "Temp directory not created"
        needed = int(required_bytes * 1.1)
        try:
            usage = shutil.disk_usage(self._temp_dir)
            ok = usage.free >= needed
            if ok:
                return True, f"Sufficient space: {usage.free:,} available"
            return False, (
                f"Insufficient temp space. Need {needed:,} bytes "
                f"({required_bytes:,} x 1.1), {usage.free:,} available"
            )
        except OSError as e:
            return False, f"Cannot check disk space: {e}"

    def cleanup(self) -> None:
        """Delete temp directory if it exists (best-effort)."""
        if self._temp_dir is not None and self._temp_dir.exists():
            shutil.rmtree(self._temp_dir, ignore_errors=True)
            self._temp_dir = None

    @staticmethod
    def cleanup_orphans() -> int:
        """Remove orphaned whatsapp-transfer-* directories.

        Returns count of cleaned directories. Runs on backend startup
        to clean up from previous crashed runs.
        """
        base = Path(tempfile.gettempdir())
        count = 0
        for entry in base.glob("whatsapp-transfer-*"):
            if entry.is_dir():
                try:
                    shutil.rmtree(entry, ignore_errors=True)
                    count += 1
                except OSError:
                    pass
        return count
