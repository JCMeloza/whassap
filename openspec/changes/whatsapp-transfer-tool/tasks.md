# Tasks: WhatsApp Transfer Tool

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 2000–2500 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 → PR 2 → PR 3 → PR 4 → PR 5 |
| Delivery strategy | auto-chain |
| Chain strategy | stacked-to-main |
| Decision needed before apply | No |
| Chain strategy | stacked-to-main |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Python backend foundation — protocol, models, ADB manager, device service | PR 1 | Base for all backend work. Tests included. ~380 lines |
| 2 | Python scanner + transfer engine + temp storage + progress reporter | PR 2 | Depends on PR 1. Core transfer logic. ~400 lines |
| 3 | Flutter foundation — main, app, models, protocol, backend client | PR 3 | Base for all Flutter work. Tests included. ~380 lines |
| 4 | Flutter screens — home, selection, transfer, completion | PR 4 | Depends on PR 3. ~400 lines |
| 5 | Integration & bundling — PyInstaller, build config, cross-platform | PR 5 | Depends on PR 1-4. ~200 lines |

## Phase 1: Python Backend Foundation

- [x] 1.1 Create `backend/protocol.py` — Request/Response/ProgressEvent/PhaseChangeEvent dataclasses with JSON serialization
- [x] 1.2 Create `backend/models.py` — Device, ScanResult, TransferConfig, ProgressEvent dataclasses
- [x] 1.3 Create `backend/adb_manager.py` — ADB binary resolution (system PATH + bundled fallback), version check, `adb start-server`/`kill-server`
- [x] 1.4 Create `backend/device_service.py` — Device enumeration (`adb devices -l`), properties (`getprop`), WhatsApp package detection (`pm list packages`)
- [x] 1.5 Create `backend/main.py` — Entry point, NDJSON I/O loop, request router, signal handling
- [x] 1.6 Write unit tests for protocol, models, ADB manager, device service (TDD: RED→GREEN→REFACTOR)

## Phase 2: Python Scanner + Transfer Engine

- [x] 2.1 Create `backend/scanner_service.py` — Legacy + scoped path scanning, size calculation, package-aware discovery, empty state handling
- [x] 2.2 Create `backend/temp_storage.py` — Temp dir creation, space check (110%), cleanup on success/cancel, orphan cleanup on startup
- [x] 2.3 Create `backend/progress_reporter.py` — ADB stderr parsing (modern + fallback), NDJSON progress emission, phase change events
- [x] 2.4 Create `backend/transfer_engine.py` — Pull→temp→push orchestration, pause/resume/cancel, package mapping, error handling
- [x] 2.5 Write unit tests for scanner, temp storage, progress reporter, transfer engine (TDD: RED→GREEN→REFACTOR)

## Phase 3: Flutter Foundation

- [x] 3.1 Create `pubspec.yaml` — Flutter deps (flutter, path, uuid, json_annotation, provider/riverpod)
- [x] 3.2 Create `lib/src/protocol/protocol.dart` — NDJSON message types, JSON serialization (mirrors Python protocol)
- [x] 3.3 Create `lib/src/models/device.dart` — Device model (serial, model, apiLevel, packages, classification)
- [x] 3.4 Create `lib/src/models/scan_result.dart` — ScanResult model (databases, media, totalBytes)
- [x] 3.5 Create `lib/src/models/transfer.dart` — Transfer state model (id, phase, progress, items)
- [x] 3.6 Create `lib/src/services/backend_client.dart` — NDJSON protocol client, process spawn, request/response correlation, event streaming
- [x] 3.7 Create `lib/src/services/device_service.dart` — Device list, properties, WhatsApp detection via backend
- [x] 3.8 Create `lib/src/services/transfer_service.dart` — Transfer orchestration, progress state, pause/resume/cancel
- [x] 3.9 Write unit tests for protocol, models, backend client, services (TDD: RED→GREEN→REFACTOR)

## Phase 4: Flutter Screens

- [x] 4.1 Create `lib/main.dart` — App entry, theme, backend process spawn
- [x] 4.2 Create `lib/src/app.dart` — MaterialApp with wizard routes (home → selection → transfer → completion)
- [x] 4.3 Create `lib/src/screens/home_screen.dart` — Welcome screen with device detection, polling, device list, unauthorized/empty states
- [x] 4.4 Create `lib/src/screens/selection_screen.dart` — Source/dest device selection, data type selection (DB + media), size summary
- [x] 4.5 Create `lib/src/screens/transfer_screen.dart` — Progress UI (phase, %, rate, ETA, current item, pause/cancel buttons)
- [x] 4.6 Create `lib/src/screens/completion_screen.dart` — Summary + restore guidance + verify-on-device + troubleshooting
- [x] 4.7 Write widget tests for all 4 screens (TDD: RED→GREEN→REFACTOR)

## Phase 5: Integration & Bundling

- [x] 5.1 Create `backend/spec/backend.spec` — PyInstaller spec for `--onefile` with ADB binary bundling
- [x] 5.2 Create `build.yaml` — Flutter build config for backend embedding (copy backend binary to build output)
- [x] 5.3 Create `pyproject.toml` — Python deps (psutil), build metadata
- [x] 5.4 Create `backend/bin/linux/adb` placeholder — Bundled ADB binary (Linux) with download script
- [x] 5.5 Create `backend/bin/windows/adb.exe` placeholder — Bundled ADB binary (Windows) with download script
- [x] 5.6 Update `README.md` — Build/run instructions for Windows and Linux
- [x] 5.7 Integration test: backend spawn → request/response round-trip → progress streaming → cancel cleanup
