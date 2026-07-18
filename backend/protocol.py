"""NDJSON protocol message types for WhatsApp Transfer Tool.

Flutter ↔ Python communication uses newline-delimited JSON over stdin/stdout.
This module defines the message dataclasses with JSON serialization.
"""

from dataclasses import dataclass, asdict
from typing import Any, Optional
import json


@dataclass
class Request:
    """Request from Flutter to Python backend."""
    id: str
    method: str
    params: dict
    type: str = "request"

    def to_json(self) -> str:
        return json.dumps(asdict(self), separators=(",", ":"))


@dataclass
class Response:
    """Response from Python backend to Flutter."""
    id: str
    type: str = "response"
    result: Optional[Any] = None
    error: Optional[dict] = None

    def to_json(self) -> str:
        d = {"type": self.type, "id": self.id}
        if self.result is not None:
            d["result"] = self.result
        if self.error is not None:
            d["error"] = self.error
        return json.dumps(d, separators=(",", ":"))


@dataclass
class ProgressEvent:
    """Real-time progress event during transfer."""
    transferId: str
    phase: str
    package: str
    item: str
    bytesTransferred: int
    bytesTotal: int
    percentage: float
    transferRateBps: float
    etaSeconds: int
    type: str = "progress"

    def to_json(self) -> str:
        return json.dumps(asdict(self), separators=(",", ":"))


@dataclass
class PhaseChangeEvent:
    """Phase transition event (pull→push→complete)."""
    transferId: str
    to: str
    type: str = "phase_change"
    from_: str = ""

    def to_json(self) -> str:
        d = {"type": self.type, "transferId": self.transferId,
             "from": self.from_, "to": self.to}
        return json.dumps(d, separators=(",", ":"))


@dataclass
class AdbInfoEvent:
    """ADB binary info emitted on backend startup."""
    data: dict
    event: str = "adb_info"
    type: str = "event"

    def to_json(self) -> str:
        d = {"type": self.type, "event": self.event, "data": self.data}
        return json.dumps(d, separators=(",", ":"))


@dataclass
class DriverIssueEvent:
    """USB driver issue event (Windows)."""
    data: dict
    event: str = "driver_issue"
    type: str = "event"

    def to_json(self) -> str:
        d = {"type": self.type, "event": self.event, "data": self.data}
        return json.dumps(d, separators=(",", ":"))
