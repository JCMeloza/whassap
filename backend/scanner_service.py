"""Scanner service for WhatsApp data discovery on Android devices.

Discovers databases and media for legacy (API <= 29) and scoped storage
(API >= 30) paths. Package-aware: only scans installed packages.
"""

import re
import subprocess
from backend.models import DatabaseInfo, MediaInfo, WhatsAppData

# Package path templates
_PATHS = {
    "com.whatsapp": {
        "db_legacy": "/sdcard/WhatsApp/Databases/",
        "media_legacy": "/sdcard/WhatsApp/Media/",
        "db_scoped": "/sdcard/Android/media/com.whatsapp/WhatsApp/Databases/",
        "media_scoped": "/sdcard/Android/media/com.whatsapp/WhatsApp/Media/",
    },
    "com.whatsapp.w4b": {
        "db_legacy": "/sdcard/WhatsApp Business/Databases/",
        "media_legacy": "/sdcard/WhatsApp Business/Media/",
        "db_scoped": "/sdcard/Android/media/com.whatsapp.w4b/WhatsApp Business/Databases/",
        "media_scoped": "/sdcard/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/",
    },
}

_MEDIA_CATEGORIES = ["Images", "Video", "Audio", "Documents", "Stickers"]
_SCOPED_FALLBACK = "/sdcard/Android/data/{pkg}/files/"


def _run_adb_shell(adb_path: str, serial: str, command: str) -> str | None:
    """Run an adb shell command, return stdout or None on failure."""
    try:
        result = subprocess.run(
            [adb_path, "-s", serial, "shell", command],
            capture_output=True, text=True, timeout=15,
        )
        return result.stdout if result.returncode == 0 else None
    except (subprocess.SubprocessError, FileNotFoundError, OSError):
        return None


def _parse_file_sizes(ls_output: str) -> list[tuple[str, str, int]]:
    """Parse `ls -la` output into (name, path, size) for .crypt*/.db files.

    Pure function — no side effects. Returns empty list for empty input.
    """
    files: list[tuple[str, str, int]] = []
    for line in ls_output.splitlines():
        line = line.strip()
        if not line or line.startswith("total") or line.startswith("d"):
            continue
        parts = line.split()
        if len(parts) < 5:
            continue
        name = parts[-1]
        if not re.search(r"\.(crypt\d+|db)$", name):
            continue
        try:
            size = int(parts[4])
        except (ValueError, IndexError):
            size = 0
        files.append((name, name, size))
    return files


def _parse_media_sizes(du_output: str) -> list[tuple[str, str, int]]:
    """Parse `du -sb` output into (name, path, size) tuples.

    Pure function — no side effects.
    """
    items: list[tuple[str, str, int]] = []
    for line in du_output.splitlines():
        line = line.strip()
        if not line:
            continue
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        try:
            size = int(parts[0])
        except ValueError:
            continue
        name = parts[-1].split("/")[-1]
        items.append((name, name, size))
    return items


class ScannerService:
    """Service for discovering WhatsApp data on Android devices."""

    def __init__(self, adb_provider):
        self._adb = adb_provider

    def scan_device(self, serial: str, packages: list[str],
                    api_level: int) -> list[WhatsAppData]:
        """Scan device for WhatsApp data for each installed package."""
        results: list[WhatsAppData] = []
        for pkg in packages:
            paths = _PATHS.get(pkg)
            if paths is None:
                continue
            db_path = paths["db_scoped" if api_level >= 30 else "db_legacy"]
            media_path = paths["media_scoped" if api_level >= 30 else "media_legacy"]

            databases = self._list_databases(serial, db_path, pkg)
            media = self._list_media(serial, media_path, pkg)

            # Fallback for scoped OEM variations
            if not media and api_level >= 30:
                fb = _SCOPED_FALLBACK.format(pkg=pkg)
                media = self._list_media(serial, fb, pkg)

            if not databases and not media:
                continue

            results.append(WhatsAppData(
                databases=databases, media=media, package=pkg,
            ))
        return results

    def _list_databases(self, serial: str, path: str,
                        pkg: str) -> list[DatabaseInfo]:
        """List database files at a given path."""
        output = _run_adb_shell(self._adb.adb_path, serial, f"ls -la {path}")
        if output is None:
            return []
        return [
            DatabaseInfo(path=path + name, name=name, sizeBytes=size,
                         package=pkg)
            for name, _, size in _parse_file_sizes(output)
        ]

    def _list_media(self, serial: str, path: str,
                    pkg: str) -> list[MediaInfo]:
        """List media subdirectories with sizes."""
        items: list[MediaInfo] = []
        for cat in _MEDIA_CATEGORIES:
            cat_path = path + cat
            output = _run_adb_shell(self._adb.adb_path, serial,
                                    f"du -sb {cat_path}")
            if output is None:
                continue
            for name, _, size in _parse_media_sizes(output):
                items.append(MediaInfo(
                    category=name, path=cat_path,
                    sizeBytes=size, package=pkg,
                ))
        return items
