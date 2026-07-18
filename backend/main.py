"""Entry point for WhatsApp Transfer Tool Python backend.

Reads NDJSON commands from stdin, routes them to handlers,
and writes NDJSON responses to stdout.
"""

import json
import sys
import signal
from typing import Optional

from backend.protocol import Request, Response
from backend.device_service import DeviceService
from backend.adb_manager import AdbManager
from backend.scanner_service import ScannerService
from backend.temp_storage import TempStorage
from backend.progress_reporter import ProgressReporter
from backend.transfer_engine import TransferEngine
from backend.models import TransferConfig


def _parse_request(line: str) -> Optional[Request]:
    """Parse a JSON line into a Request object.

    Returns None if the JSON is invalid or missing required fields.
    """
    try:
        data = json.loads(line)
    except (json.JSONDecodeError, ValueError):
        return None
    if not isinstance(data, dict):
        return None
    req_id = data.get("id")
    method = data.get("method")
    params = data.get("params")
    if not req_id or not method or params is None:
        return None
    return Request(id=str(req_id), method=str(method), params=params)


class RequestRouter:
    """Routes parsed requests to registered method handlers."""

    def __init__(self, adb: AdbManager, device_service: DeviceService,
                 scanner: ScannerService, temp_storage: TempStorage,
                 engine: TransferEngine):
        self._adb = adb
        self._device = device_service
        self._scanner = scanner
        self._temp = temp_storage
        self._engine = engine
        self._routes: dict[str, callable] = {
            "device.list": self._handle_device_list,
            "device.properties": self._handle_device_properties,
            "device.packages": self._handle_device_packages,
            "scanner.scan": self._handle_scanner_scan,
            "transfer.start": self._handle_transfer_start,
            "transfer.pause": self._handle_transfer_pause,
            "transfer.cancel": self._handle_transfer_cancel,
        }

    def handle(self, req: Request) -> Response:
        """Route a request to its handler, returning a Response."""
        handler = self._routes.get(req.method)
        if handler is None:
            return Response(
                id=req.id,
                error={"code": "METHOD_NOT_FOUND",
                       "message": f"Unknown method: {req.method}"},
            )
        try:
            return handler(req)
        except Exception as e:
            return Response(
                id=req.id,
                error={"code": "INTERNAL_ERROR", "message": str(e)},
            )

    def _handle_device_list(self, req: Request) -> Response:
        devices = self._device.get_device_info()
        result = {
            "devices": [
                {
                    "serial": d.serial,
                    "model": d.model,
                    "apiLevel": d.apiLevel,
                    "packages": d.packages,
                    "classification": d.classification,
                }
                for d in devices
            ]
        }
        return Response(id=req.id, result=result)

    def _handle_device_properties(self, req: Request) -> Response:
        serial = req.params.get("serial", "")
        props = self._device.get_properties(serial)
        return Response(id=req.id, result=props)

    def _handle_device_packages(self, req: Request) -> Response:
        serial = req.params.get("serial", "")
        packages = self._device.detect_packages(serial)
        return Response(id=req.id, result={"packages": packages})

    def _handle_scanner_scan(self, req: Request) -> Response:
        serial = req.params.get("serial", "")
        packages = req.params.get("packages", [])
        api_level = req.params.get("apiLevel", 0)
        results = self._scanner.scan_device(serial, packages, api_level)
        return Response(id=req.id, result={
            "scanResults": [
                {
                    "package": r.package,
                    "databases": [
                        {"path": d.path, "name": d.name,
                         "sizeBytes": d.sizeBytes, "package": d.package}
                        for d in r.databases
                    ],
                    "media": [
                        {"category": m.category, "path": m.path,
                         "sizeBytes": m.sizeBytes, "package": m.package}
                        for m in r.media
                    ],
                    "totalBytes": r.totalBytes,
                }
                for r in results
            ],
        })

    def _handle_transfer_start(self, req: Request) -> Response:
        config = TransferConfig(
            sourceSerial=req.params.get("source", ""),
            destSerial=req.params.get("dest", ""),
            packages=req.params.get("packages", []),
            items=req.params.get("items", []),
        )
        transfer_id = self._engine.start(config)
        return Response(id=req.id, result={"transferId": transfer_id})

    def _handle_transfer_pause(self, req: Request) -> Response:
        transfer_id = req.params.get("transferId", "")
        self._engine.pause(transfer_id)
        return Response(id=req.id, result={"status": "paused"})

    def _handle_transfer_cancel(self, req: Request) -> Response:
        transfer_id = req.params.get("transferId", "")
        self._engine.cancel(transfer_id)
        return Response(id=req.id, result={"status": "cancelled"})


def main() -> None:
    """Main entry point: read NDJSON from stdin, write to stdout."""
    signal.signal(signal.SIGINT, lambda s, f: sys.exit(0))

    adb = AdbManager()
    device_service = DeviceService(adb)
    scanner = ScannerService(adb)
    temp_storage = TempStorage()
    reporter = ProgressReporter(transfer_id="")
    engine = TransferEngine(adb, scanner, temp_storage, reporter, device_service)
    router = RequestRouter(adb, device_service, scanner, temp_storage, engine)

    # Clean up orphaned temp directories from previous runs
    orphan_count = TempStorage.cleanup_orphans()

    # Emit ADB info event on startup
    adb_info = json.dumps({
        "type": "event",
        "event": "adb_info",
        "data": {
            "path": adb.adb_path,
            "version": adb.version or "unknown",
            "source": adb.source,
        },
    }, separators=(",", ":"))
    sys.stdout.write(adb_info + "\n")
    sys.stdout.flush()

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        req = _parse_request(line)
        if req is None:
            err = json.dumps({
                "type": "response",
                "error": {"code": "INVALID_REQUEST",
                          "message": "Invalid JSON or missing fields"},
            }, separators=(",", ":"))
            sys.stdout.write(err + "\n")
            sys.stdout.flush()
            continue
        resp = router.handle(req)
        sys.stdout.write(resp.to_json() + "\n")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
