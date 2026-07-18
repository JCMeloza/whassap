# Design: WhatsApp Transfer Tool

## Technical Approach

Flutter Desktop (Windows/Linux) acts as the UI orchestrator, spawning a Python backend subprocess bundled via PyInstaller. Communication uses NDJSON over stdin/stdout. The Python backend handles all ADB interactions: device detection, data discovery, transfer orchestration (pull→temp→push), progress parsing, temp storage management, and ADB binary management with bundled fallback. Flutter drives a 4-step wizard (Detect → Select Data → Transfer → Done) and renders real-time progress from NDJSON events.

---

## Architecture Decisions

| Decision | Choice | Alternatives Considered | Rationale |
|----------|--------|------------------------|-----------|
| **UI ↔ Backend IPC** | NDJSON over stdio (subprocess) | gRPC, HTTP/localhost, WebSocket | Zero-config, no port conflicts, works cross-platform without firewall issues, natural streaming for progress events |
| **Python Backend Bundling** | PyInstaller `--onefile` per platform | Nuitka, cx_Freeze, shiv/pyz | PyInstaller is mature, handles binary bundling (ADB), single-file output embeds cleanly in Flutter bundle |
| **ADB Binary Strategy** | Bundled ADB per platform (win/linux) with system PATH fallback | System ADB only, download at runtime | Bundled guarantees version ≥34 (progress support), works offline, no driver conflicts; system ADB preferred if ≥31 |
| **ADB Communication** | Subprocess per command (`adb shell`, `adb pull`, `adb push`) | `adb shell` persistent session, `adb sync` | Per-command is simpler, survives ADB server restarts, progress parsing works on stderr naturally |
| **Temp Directory** | `tempfile.gettempdir()/whatsapp-transfer-<uuid>/` with `0o700` | Fixed path, user-selected | Unique per transfer prevents collisions; `0o700` protects WhatsApp data; auto-cleanup on success/cancel |
| **Progress Parsing** | Parse modern ADB stderr (`45% 12.3 MB/s 2.1GB/4.7GB`); fallback pre-scan + byte counting | ADB `sync` protocol, custom protocol | Modern ADB stderr parsing is reliable; fallback handles older ADB without protocol changes |
| **Transfer Protocol** | Pull → temp dir → Push (v1) | Streaming pull→push (v2) | Temp dir enables pause/resume/cancel, space check, failure inspection; streaming is v2 optimization |
| **Package Mapping** | 1:1 by package name (`com.whatsapp`↔`com.whatsapp`, `com.whatsapp.w4b`↔`com.whatsapp.w4b`) | Cross-package mapping | WhatsApp restores only same-package data; cross-package would fail restore |
| **Flutter Backend Launch** | `Process.start` with `stdio: [Pipe, Pipe, Pipe]`, backend path resolved relative to Flutter executable | Fixed path, environment variable | Relative path works for bundled app; pipes enable NDJSON streaming |
| **Temp Cleanup Strategy** | Success: delete after `phase_change` to `complete`; Cancel: kill ADB + immediate `rmtree`; Failure: preserve + report path; Startup: orphan cleanup via PID lock file | Always keep, manual cleanup only | Preserves debuggability on failure; auto-clean on success/cancel prevents disk bloat |
| **ADB Server Management** | `adb start-server` on backend start; `adb kill-server` optional on shutdown | Leave server running | Explicit start ensures bundled ADB works; optional kill avoids breaking other ADB tools |
| **Progress Event Frequency** | NDJSON every ≤2s or on % change (ADB stderr parsing) | Fixed interval polling | ADB stderr is event-driven; 2s cap ensures UI responsiveness even on slow transfers |

---

## Data Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              FLUTTER UI (Dart)                               │
│  ┌──────────┐  ┌──────────────┐  ┌──────────────┐  ┌────────────────────┐  │
│  │  Home    │→ │  Selection   │→ │  Transfer    │→ │   Completion       │  │
│  │  Screen  │  │  Screen      │  │  Screen      │  │   Screen           │  │
│  └────┬─────┘  └──────┬───────┘  └──────┬───────┘  └────────┬───────────┘  │
│       │               │                 │                   │              │
│       ▼               ▼                 ▼                   ▼              │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                    TransferController (State)                        │  │
│  │  - devices, selection, transferId, progress, phase, errors          │  │
│  └────────────────────────────────────┬─────────────────────────────────┘  │
│                                       │                                    │
│                                       ▼                                    │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                    BackendClient (NDJSON over stdio)                 │  │
│  │  - spawns Python backend subprocess                                  │  │
│  │  - request/response correlation via UUID                             │  │
│  │  - streams progress/events to controller                             │  │
│  └────────────────────────────────────┬─────────────────────────────────┘  │
└───────────────────────────────────────│────────────────────────────────────┘
                                        │ NDJSON over stdin/stdout
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           PYTHON BACKEND (subprocess)                        │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────────────┐  │
│  │  RequestRouter   │  │  AdbManager      │  │  TransferEngine          │  │
│  │  - routes JSON   │  │  - adb binary    │  │  - pull phase            │  │
│  │    to handlers   │  │    detection     │  │  - push phase            │  │
│  └────────┬─────────┘  │  - server mgmt   │  │  - pause/resume/cancel   │  │
│           │            │  - version check │  │  - progress parsing      │  │
│           ▼            └────────┬─────────┘  └────────────┬─────────────┘  │
│  ┌─────────────────────────────┴──────────────────────────┴────────────┐  │
│  │                    Service Layer                                     │  │
│  │  ┌─────────────────┐ ┌──────────────────┐ ┌─────────────────────┐  │
│  │  │ DeviceService   │ │ ScannerService   │ │ TempStorageService  │  │
│  │  │ - list devices  │ │ - legacy scan    │ │ - create temp dir   │  │
│  │  │ - get props     │ │ - scoped scan    │ │ - space check       │  │
│  │  │ - detect WA pkg │ │ - size calc      │ │ - cleanup policies  │  │
│  │  └─────────────────┘ └──────────────────┘ └─────────────────────┘  │
│  └─────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

**NDJSON Protocol (Flutter → Python):**
```json
{"type": "request", "id": "uuid", "method": "device.list", "params": {}}
{"type": "request", "id": "uuid", "method": "device.properties", "params": {"serial": "abc123"}}
{"type": "request", "id": "uuid", "method": "scanner.scan", "params": {"serial": "abc123", "packages": ["com.whatsapp"]}}
{"type": "request", "id": "uuid", "method": "transfer.start", "params": {"source": "abc123", "dest": "def456", "packages": ["com.whatsapp"], "items": ["Databases/msgstore.db.crypt14", "Media/Images/"]}}
{"type": "request", "id": "uuid", "method": "transfer.pause", "params": {"transferId": "uuid"}}
{"type": "request", "id": "uuid", "method": "transfer.resume", "params": {"transferId": "uuid"}}
{"type": "request", "id": "uuid", "method": "transfer.cancel", "params": {"transferId": "uuid"}}
{"type": "request", "id": "uuid", "method": "verify.destination", "params": {"serial": "def456", "package": "com.whatsapp"}}
```

**NDJSON Protocol (Python → Flutter):**
```json
{"type": "response", "id": "uuid", "result": {"devices": [{"serial": "...", "model": "...", "apiLevel": 29, "packages": ["com.whatsapp"]}]}}
{"type": "response", "id": "uuid", "result": {"databases": [...], "media": [...], "totalBytes": 5000000000}}
{"type": "progress", "transferId": "uuid", "phase": "pull", "package": "com.whatsapp", "item": "Media/Images/IMG_1.jpg", "bytesTransferred": 1000000, "bytesTotal": 5000000000, "percentage": 0.02, "transferRateBps": 12000000, "etaSeconds": 400}
{"type": "phase_change", "transferId": "uuid", "from": "pull", "to": "push"}
{"type": "event", "event": "adb_info", "data": {"path": "/path/to/adb", "version": "34.0.5", "source": "bundled"}}
{"type": "event", "event": "driver_issue", "data": {"message": "..."}}
{"type": "response", "id": "uuid", "error": {"code": "INSUFFICIENT_SPACE", "message": "Need 16.5 GB, 10 GB available"}}
```

---

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/main.dart` | Create | App entry, routes, theme, backend process spawn |
| `lib/src/app.dart` | Create | MaterialApp with wizard routes |
| `lib/src/screens/home_screen.dart` | Create | Welcome + device detection start |
| `lib/src/screens/selection_screen.dart` | Create | Source/dest device + data selection |
| `lib/src/screens/transfer_screen.dart` | Create | Progress UI (phase, %, rate, ETA, pause/cancel) |
| `lib/src/screens/completion_screen.dart` | Create | Summary + restore guidance + verify button |
| `lib/src/services/backend_client.dart` | Create | NDJSON protocol, process management, request/response correlation |
| `lib/src/services/device_service.dart` | Create | Device list, properties, WhatsApp detection via backend |
| `lib/src/services/transfer_service.dart` | Create | Transfer orchestration, progress state |
| `lib/src/models/device.dart` | Create | Device model (serial, model, apiLevel, packages, classification) |
| `lib/src/models/scan_result.dart` | Create | Databases + media with sizes |
| `lib/src/models/transfer.dart` | Create | Transfer state (id, phase, progress, items) |
| `lib/src/protocol/protocol.dart` | Create | NDJSON message types, serialization |
| `backend/main.py` | Create | Entry point, request router, NDJSON I/O loop, signal handling |
| `backend/adb_manager.py` | Create | ADB binary resolution, version check, server lifecycle |
| `backend/device_service.py` | Create | Device enumeration, properties, package detection |
| `backend/scanner_service.py` | Create | Legacy + scoped path scanning, size calculation |
| `backend/transfer_engine.py` | Create | Pull→temp→push orchestration, pause/resume/cancel, progress parsing |
| `backend/temp_storage.py` | Create | Temp dir lifecycle, space check, orphan cleanup |
| `backend/progress_reporter.py` | Create | ADB stderr parsing, fallback byte counting, NDJSON emission |
| `backend/protocol.py` | Create | Request/response/event dataclasses, JSON serialization |
| `backend/models.py` | Create | Device, ScanResult, TransferConfig, ProgressEvent dataclasses |
| `backend/bin/windows/adb.exe` | Add | Bundled ADB (Windows) + DLLs |
| `backend/bin/linux/adb` | Add | Bundled ADB (Linux) |
| `backend/spec/backend.spec` | Create | PyInstaller spec for --onefile bundling |
| `build.yaml` | Create | Flutter build config (backend embedding) |
| `pubspec.yaml` | Create | Flutter dependencies (flutter, path, uuid, etc.) |
| `pyproject.toml` | Create | Python deps (psutil, pyyaml for config) |
| `README.md` | Update | Build/run instructions for both platforms |

---

## Interfaces / Contracts

**Python: `backend/protocol.py`**
```python
from dataclasses import dataclass
from typing import Any, Optional
from uuid import UUID
import json

@dataclass
class Request:
    type: str = "request"
    id: str
    method: str
    params: dict

@dataclass
class Response:
    type: str = "response"
    id: str
    result: Optional[Any] = None
    error: Optional[dict] = None  # {"code": "...", "message": "..."}

    def to_json(self) -> str:
        d = {"type": self.type, "id": self.id}
        if self.result is not None:
            d["result"] = self.result
        if self.error is not None:
            d["error"] = self.error
        return json.dumps(d, separators=(",", ":"))

@dataclass
class ProgressEvent:
    type: str = "progress"
    transferId: str
    phase: str  # "pull" | "push"
    package: str
    item: str
    bytesTransferred: int
    bytesTotal: int
    percentage: float
    transferRateBps: float
    etaSeconds: int

@dataclass
class PhaseChangeEvent:
    type: str = "phase_change"
    transferId: str
    from_: str  # "pull" | "push" | "complete"
    to: str     # "push" | "complete"

@dataclass
class AdbInfoEvent:
    type: str = "event"
    event: str = "adb_info"
    data: dict  # {"path": "...", "version": "...", "source": "bundled|system"}

@dataclass
class DriverIssueEvent:
    type: str = "event"
    event: str = "driver_issue"
    data: dict  # {"message": "..."}

# Method names (Flutter → Python):
# device.list, device.properties, scanner.scan, transfer.start, 
# transfer.pause, transfer.resume, transfer.cancel, verify.destination
```

**Flutter: `lib/src/protocol/protocol.dart`**
```dart
// Mirrors Python protocol with json_serializable
@JsonSerializable()
class Request {
  final String type = 'request';
  final String id;
  final String method;
  final Map<String, dynamic> params;
  // toJson/fromJson generated
}

@JsonSerializable()
class Response {
  final String type = 'response';
  final String id;
  final dynamic result;
  final ProtocolError? error;
}

@JsonSerializable()
class ProgressEvent {
  final String type = 'progress';
  final String transferId;
  final String phase; // 'pull' | 'push'
  final String package;
  final String item;
  final int bytesTransferred;
  final int bytesTotal;
  final double percentage;
  final double transferRateBps;
  final int etaSeconds;
}

@JsonSerializable()
class PhaseChangeEvent {
  final String type = 'phase_change';
  final String transferId;
  @JsonKey(name: 'from')
  final String fromPhase;
  final String toPhase;
}
```

---

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| **Unit (Python)** | ADB output parsing (device list, properties, progress lines), path resolution (legacy vs scoped), temp space calc, package mapping, protocol serialization | `unittest` with fixture ADB outputs; parametrize API levels & package combos |
| **Unit (Flutter)** | Protocol (de)serialization, TransferController state machine, progress aggregation, device/selection logic | `flutter_test` with mock BackendClient; golden tests for progress UI |
| **Integration (Python)** | Full device→scan→transfer flow against real ADB (requires device), PyInstaller binary smoke test | `unittest` with `@unittest.skipIf(no_device)`; CI on device farm for v2 |
| **Integration (Flutter)** | Backend spawn → request/response round-trip → progress streaming → cancel cleanup | `flutter_test` with real backend binary; temp dir cleanup verification |
| **E2E (Manual v1)** | Windows/Linux build → zip → run on clean machine → detect device → transfer 100MB → verify restore | Manual QA checklist per platform |

---

## Migration / Rollout

- **No data migration** — greenfield tool, no prior version.
- **Rollout**: v1 = zip distribution (Windows/Linux). v2 = installers (NSIS, AppImage).
- **Feature flag**: Bundled ADB vs system ADB (auto-detect, no user toggle in v1).
- **Rollback**: User deletes app folder; no system installation, no persistent state except temp dirs (auto-cleaned on next run).

---

## Open Questions

- [ ] **Streaming pull→push (v2)**: Can `adb pull -` stdout pipe to `adb push -` stdin? Need ADB version testing.
- [ ] **Incremental manifest (v2)**: Store manifest.json in temp dir for resume-after-crash.
- [ ] **Linux packaging priority**: AppImage vs Flatpak vs Snap — target distro survey needed.
- [ ] **Windows ARM64**: Add to v1 or v2? PyInstaller + Flutter both support; test hardware needed.
- [ ] **Multi-device UI**: Radio buttons vs dropdown for >2 devices — UX decision needed.

---

## Next Step

Ready for tasks (sdd-tasks).