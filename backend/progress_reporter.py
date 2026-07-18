"""Progress reporter for WhatsApp Transfer Tool.

Parses ADB stderr for real-time progress (modern ADB 34+), provides
fallback estimation for older ADB, and emits NDJSON progress/phase
change events to stdout for the Flutter frontend.
"""

import re
import sys
from backend.protocol import ProgressEvent, PhaseChangeEvent


def parse_adb_progress(line: str) -> dict | None:
    """Parse modern ADB stderr progress line.

    Expected format: "45% 12.3 MB/s 2.1GB/4.7GB 00:12"
    Returns dict with percentage, bytesTransferred, bytesTotal,
    transferRateBps, or None if line does not match.

    Pure function — no side effects.
    """
    pattern = r"(\d+)%\s+([\d.]+)\s+(\w+)/s\s+([\d.]+)(\w+)/([\d.]+)(\w+)"
    match = re.search(pattern, line)
    if not match:
        return None

    percentage = int(match.group(1))
    rate = float(match.group(2))
    trans_num = float(match.group(4))
    trans_unit = match.group(5)
    total_num = float(match.group(6))
    total_unit = match.group(7)

    unit_map = {"B": 1, "KB": 1024, "MB": 1024 ** 2,
                "GB": 1024 ** 3, "TB": 1024 ** 4}
    to_bytes = lambda n, u: int(n * unit_map.get(u, 1))

    return {
        "percentage": percentage,
        "bytesTransferred": to_bytes(trans_num, trans_unit),
        "bytesTotal": to_bytes(total_num, total_unit),
        "transferRateBps": int(rate * unit_map.get(match.group(3), 1)),
    }


def estimate_eta(percentage: float, elapsed_seconds: float) -> int:
    """Estimate remaining transfer time in seconds.

    Pure function — uses linear extrapolation from current progress.
    Returns 0 when no progress or transfer is complete.
    """
    if percentage <= 0 or percentage >= 100:
        return 0
    total_est = elapsed_seconds / (percentage / 100.0)
    return max(0, int(total_est - elapsed_seconds))


class ProgressReporter:
    """Reports transfer progress via NDJSON events to stdout."""

    def __init__(self, transfer_id: str):
        self._transfer_id = transfer_id

    def emit_progress(self, phase: str, package: str, item: str,
                      bytes_transferred: int, bytes_total: int,
                      percentage: float, transfer_rate_bps: float,
                      eta_seconds: int) -> None:
        """Emit a progress event as NDJSON to stdout."""
        evt = ProgressEvent(
            transferId=self._transfer_id,
            phase=phase,
            package=package,
            item=item,
            bytesTransferred=bytes_transferred,
            bytesTotal=bytes_total,
            percentage=round(percentage, 1),
            transferRateBps=transfer_rate_bps,
            etaSeconds=eta_seconds,
        )
        self._write(evt.to_json())

    def emit_phase_change(self, from_: str, to: str) -> None:
        """Emit a phase change event (e.g. pull->push)."""
        evt = PhaseChangeEvent(
            transferId=self._transfer_id, from_=from_, to=to,
        )
        self._write(evt.to_json())

    @staticmethod
    def _write(json_str: str) -> None:
        """Write a JSON line to stdout (NDJSON) and flush."""
        sys.stdout.write(json_str + "\n")
        sys.stdout.flush()
