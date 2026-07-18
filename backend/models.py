"""Data models for WhatsApp Transfer Tool.

Core domain types used across the backend for device information,
scan results, transfer configuration, and progress tracking.
"""

from dataclasses import dataclass, field
from typing import Optional


@dataclass
class DeviceInfo:
    """Information about a detected Android device."""
    serial: str
    model: str
    apiLevel: int
    packages: list[str]

    @property
    def classification(self) -> str:
        """'legacy' for API ≤ 29, 'scoped' for API ≥ 30."""
        return "legacy" if self.apiLevel <= 29 else "scoped"


@dataclass
class DatabaseInfo:
    """A WhatsApp database file on the device."""
    path: str
    name: str
    sizeBytes: int
    package: str


@dataclass
class MediaInfo:
    """A WhatsApp media category on the device."""
    category: str
    path: str
    sizeBytes: int
    package: str


@dataclass
class WhatsAppData:
    """Aggregated WhatsApp data from a scan."""
    databases: list[DatabaseInfo]
    media: list[MediaInfo]
    package: str

    @property
    def totalBytes(self) -> int:
        return sum(db.sizeBytes for db in self.databases) + \
               sum(m.sizeBytes for m in self.media)


@dataclass
class TransferConfig:
    """Configuration for a transfer operation."""
    sourceSerial: str
    destSerial: str
    packages: list[str]
    items: list[str]


@dataclass
class TransferProgress:
    """Real-time progress of a transfer."""
    transferId: str
    phase: str
    itemsTotal: int = 0
    itemsCompleted: int = 0
    bytesTotal: int = 0
    bytesTransferred: int = 0

    @property
    def percentage(self) -> float:
        if self.bytesTotal == 0:
            return 0.0
        return round(self.bytesTransferred / self.bytesTotal * 100, 1)
