# WhatsApp Transfer Tool

Transfer WhatsApp data (databases + media) between Android devices via ADB.

A **Flutter Desktop** app with a **Python backend** — the Flutter UI drives a 4-step
wizard while the Python backend handles all ADB interactions via a subprocess protocol
using NDJSON over stdin/stdout.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Flutter UI (Dart)                  │
│  Home → Select Data → Transfer → Completion (Wizard) │
│         ↕ NDJSON (stdin/stdout pipes)                │
│            Python Backend (subprocess)                │
│        ADB → device.list / scanner.scan / etc.       │
└─────────────────────────────────────────────────────┘
```

- **Flutter** manages the UI, user input, and real-time progress rendering.
- **Python** handles all ADB operations: device detection, data scanning, pull→push
  transfer, progress parsing, and temp storage management.
- **Protocol**: JSON Lines (NDJSON) over stdin/stdout — no ports, no configuration.

### Stack

| Layer     | Technology                  | Notes                            |
|-----------|-----------------------------|----------------------------------|
| UI        | Flutter 3.44+ (Dart)        | Linux & Windows desktop          |
| Backend   | Python 3.10+                | Bundled via PyInstaller          |
| IPC       | NDJSON over stdio pipes     | Request/response + event stream  |
| ADB       | Platform-tools ≥ 31         | Bundled with app, system fallback |
| State     | Provider (Flutter)          | Reactive state management        |

## Prerequisites

- **Flutter** 3.44+ with Linux or Windows desktop support
  - `flutter config --enable-linux-desktop` (Linux)
  - `flutter config --enable-windows-desktop` (Windows)
- **Python** 3.10+ (`python3` on PATH)
- **ADB** (optional) — if available on system PATH, the backend prefers it;
  otherwise uses the bundled binary. Run `download-adb.sh` (Linux) or
  `download-adb.bat` (Windows) to download platform-tools.
- **curl** (for downloading ADB via the provided scripts)
- **unzip** (Linux) or built-in archive support (Windows)

## Quick Start

### 1. Clone and install dependencies

```bash
git clone <repo-url> && cd whatsapp_transfer

# Flutter dependencies
flutter pub get

# Python dependencies
pip install psutil
```

### 2. Download ADB (optional — only if system ADB is unavailable)

```bash
# Linux
bash backend/bin/linux/download-adb.sh

# Windows
backend\bin\windows\download-adb.bat
```

### 3. Run in development mode

```bash
# Start the backend manually (for testing)
python3 -m backend.main

# In another terminal, run Flutter
flutter run -d linux
```

### 4. Run tests

```bash
# Python backend tests
python3 -m unittest discover -s backend/tests -p "test_*.py" -v

# Flutter tests
flutter test
```

## Build & Bundle

### Linux

```bash
# 1. Build Flutter
flutter build linux --release

# 2. Build Python backend binary
cd backend && pyinstaller --onefile spec/backend.spec && cd ..

# 3. Bundle backend into Flutter output
mkdir -p build/linux/x64/release/bundle/backend/bin
cp backend/dist/whatsapp-backend build/linux/x64/release/bundle/backend/
cp backend/bin/linux/adb build/linux/x64/release/bundle/backend/bin/
chmod +x build/linux/x64/release/bundle/backend/whatsapp-backend
chmod +x build/linux/x64/release/bundle/backend/bin/adb

# 4. Package for distribution
tar -czf whatsapp-transfer-linux.tar.gz -C build/linux/x64/release/bundle .
```

### Windows

```powershell
# 1. Build Flutter
flutter build windows --release

# 2. Build Python backend binary
cd backend
pyinstaller --onefile spec/backend.spec
cd ..

# 3. Bundle backend into Flutter output
mkdir build\windows\x64\runner\Release\backend\bin
copy backend\dist\whatsapp-backend.exe build\windows\x64\runner\Release\backend\
copy backend\bin\windows\adb.exe build\windows\x64\runner\Release\backend\bin\
copy backend\bin\windows\AdbWinApi.dll build\windows\x64\runner\Release\backend\bin\
copy backend\bin\windows\AdbWinUsbApi.dll build\windows\x64\runner\Release\backend\bin\

# 4. Package for distribution
Compress-Archive -Path build\windows\x64\runner\Release\* -DestinationPath whatsapp-transfer-windows.zip
```

See `build.yaml` for detailed build documentation.

## Usage

The app guides you through a 4-step wizard:

### Step 1: Detect Devices

Connect both Android devices via USB with USB debugging enabled.
The app detects connected devices and shows their models, API levels,
and WhatsApp installation status.

### Step 2: Select Data

- Choose **source device** (the old phone with WhatsApp data)
- Choose **destination device** (the new phone to restore to)
- Select **data types** to transfer:
  - **Databases**: `msgstore.db`, `wa.db`, etc.
  - **Media**: Images, videos, audio, documents, stickers
- Review the estimated data size before proceeding

### Step 3: Transfer

The backend:
1. Pulls data from the source device to a temp directory
2. Validates space on the destination device (110% headroom)
3. Pushes data to the destination device

Real-time progress shows:
- Current phase (pull → push)
- File being transferred
- Transfer speed and ETA
- Overall percentage

Pause, resume, or cancel the transfer at any time.

### Step 4: Done

- Summary of transferred data
- Restore guidance for the destination device
- "Verify on device" button to check restore status
- Troubleshooting tips for common issues

## Development

### Project Structure

```
whatsapp_transfer/
├── lib/                          # Flutter UI
│   ├── main.dart                 # App entry, theme, backend spawn
│   ├── src/
│   │   ├── app.dart              # MaterialApp with wizard routes
│   │   ├── screens/              # 4 wizard screens
│   │   │   ├── home_screen.dart
│   │   │   ├── selection_screen.dart
│   │   │   ├── transfer_screen.dart
│   │   │   └── completion_screen.dart
│   │   ├── services/             # Backend client, device, transfer
│   │   │   ├── backend_client.dart
│   │   │   ├── device_service.dart
│   │   │   └── transfer_service.dart
│   │   ├── models/               # Device, ScanResult, Transfer
│   │   │   ├── device.dart
│   │   │   ├── scan_result.dart
│   │   │   └── transfer.dart
│   │   └── protocol/             # NDJSON protocol types
│   │       └── protocol.dart
├── backend/                      # Python backend
│   ├── main.py                   # Entry point, NDJSON router
│   ├── protocol.py               # Request/Response/Event types
│   ├── models.py                 # Data models
│   ├── adb_manager.py            # ADB binary resolution + lifecycle
│   ├── device_service.py         # Device enumeration + properties
│   ├── scanner_service.py        # Data scanning (legacy + scoped)
│   ├── temp_storage.py           # Temp dir + cleanup
│   ├── progress_reporter.py      # ADB progress parsing
│   ├── transfer_engine.py        # Pull→temp→push orchestration
│   ├── spec/
│   │   └── backend.spec          # PyInstaller spec for --onefile
│   ├── bin/
│   │   ├── linux/                # Linux ADB binary + download script
│   │   └── windows/              # Windows ADB binary + download script
│   └── tests/                    # Python unit + integration tests
├── pyproject.toml                # Python package metadata
├── build.yaml                    # Build bundling documentation
├── pubspec.yaml                  # Flutter dependencies
└── README.md                     # This file
```

### NDJSON Protocol

**Flutter → Python (request):**
```json
{"type":"request","id":"uuid","method":"device.list","params":{}}
```

**Python → Flutter (response):**
```json
{"type":"response","id":"uuid","result":{"devices":[{"serial":"...","model":"...","apiLevel":29}]}}
```

**Python → Flutter (progress):**
```json
{"type":"progress","transferId":"uuid","phase":"pull","package":"com.whatsapp","item":"Media/Images/IMG_1.jpg","bytesTransferred":1000000,"bytesTotal":5000000000,"percentage":0.02,"transferRateBps":12000000,"etaSeconds":400}
```

**Python → Flutter (events):**
```json
{"type":"event","event":"adb_info","data":{"path":"/usr/bin/adb","version":"34.0.5","source":"system"}}
```

### Testing Strategy

| Layer            | Approach                              |
|------------------|---------------------------------------|
| Python unit      | `unittest` with fixture ADB outputs    |
| Python integration | Subprocess spawn + NDJSON round-trip |
| Flutter unit     | Widget tests with mock BackendClient   |
| Flutter golden   | Screenshot comparison for progress UI  |
| E2E (v1)         | Manual QA checklist per platform       |

### ADB Compatibility

| ADB Version | Support | Notes                           |
|-------------|---------|---------------------------------|
| ≥ 34        | Full    | Modern progress parsing         |
| 31–33       | Limited | Fallback byte counting          |
| < 31        | Not recommended | May lack progress output |

## License

MIT
