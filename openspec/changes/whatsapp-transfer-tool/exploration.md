# Exploration: WhatsApp Transfer Tool

## 1. WhatsApp Data Structure on Android

### Storage Paths (by Android version)

| Android Version | WhatsApp Path | WhatsApp Business Path |
|----------------|---------------|----------------------|
| Android 11+ (API 30+) | `/sdcard/Android/media/com.whatsapp/WhatsApp/` | `/sdcard/Android/media/com.whatsapp.w4b/WhatsApp Business/` |
| Android 10 and below | `/sdcard/WhatsApp/` | `/sdcard/WhatsApp Business/` |
| Very old (pre-API 29) | `/sdcard/Android/data/com.whatsapp/files/` | `/sdcard/Android/data/com.whatsapp.w4b/files/` |

### Database Files

```
Databases/
├── msgstore.db.crypt15          ← Latest full backup (most important)
├── msgstore-YYYY-MM-DD.1.db.crypt15  ← Rolling daily backups (last few days)
└── msgstore-increment.db.crypt15      ← Incremental (less useful for transfer)
```

- **crypt15** is the current format (AES-256-GCM, protobuf-prefixed). Used since ~2021.
- **crypt14** is legacy but still found on older devices. Different header format.
- **crypt12** is very old; unlikely but possible.
- The encryption is end-to-end — we DO NOT decrypt. We just copy files. WhatsApp on the new phone handles decryption during restore.

### Media Folders

```
Media/
├── WhatsApp Images/          ← Photos (IMG-YYYYMMDD-WA####.jpg)
│   └── Sent/                 ← Sent photos
├── WhatsApp Video/           ← Videos (VID-YYYYMMDD-WA####.mp4)
│   └── Sent/
├── WhatsApp Audio/           ← Audio files (AUD-YYYYMMDD-WA####.mp3)
├── WhatsApp Voice Notes/     ← Voice messages (PTT-YYYYMMDD-WA####.opus)
│   └── 202401/               ← Organized by year-month
├── WhatsApp Documents/       ← PDFs, docs (DOC-YYYYMMDD-WA####.{ext})
│   └── Sent/
├── WhatsApp Animated Gifs/   ← GIFs
├── WhatsApp Stickers/        ← Sticker images
└── WhatsApp Profile Photos/  ← Contact profile pics
```

### Key Insight: Scoped Storage (Android 11+)

Android 11 introduced Scoped Storage. WhatsApp moved data to `Android/media/com.whatsapp/` to comply. This path is **readable by other apps via ADB** without root. This is exactly what makes our tool viable.

### WhatsApp vs WhatsApp Business

- **Regular WhatsApp**: package `com.whatsapp`
- **WhatsApp Business**: package `com.whatsapp.w4b`
- Same folder structure, different base paths
- Our tool must detect which is installed and handle both

---

## 2. ADB Capabilities Needed

### Core Commands

| Command | Purpose | Output |
|---------|---------|--------|
| `adb devices -l` | List connected devices | Serial, state, model, transport |
| `adb -s <serial> shell getprop ro.build.version.sdk` | Get Android API level | Integer (30 = Android 11) |
| `adb -s <serial> shell pm list packages \| grep -E "com.whatsapp($\| )"` | Detect WhatsApp installed | Package name or empty |
| `adb -s <serial> shell ls -la <path>` | Check if path exists | File listing or error |
| `adb -s <serial> shell du -sh <path>` | Get folder size | Size string (e.g., "2.3G") |
| `adb -s <serial> pull <remote> <local>` | Copy from device to PC | Progress, completion |
| `adb -s <serial> push <local> <remote>` | Copy from PC to device | Progress, completion |
| `adb -s <serial> shell mkdir -p <path>` | Create directory on device | Success/error |

### Device Detection Flow

```
adb devices -l
  → Parse output: serial, state, model, usb connection
  → Filter for state == "device" (connected and authorized)
  → For each device, run:
    - adb -s <serial> shell getprop ro.build.version.sdk  → Android version
    - adb -s <serial> shell pm list packages | grep whatsapp  → WhatsApp presence
    - adb -s <serial> shell pm list packages | grep w4b  → WhatsApp Business presence
```

### ADB Output Parsing

`adb devices -l` output format:
```
List of devices attached
SERIAL1          device usb:1-1 product:xxx model:Pixel_7 transport_id:1
SERIAL2          device usb:2-3 product:xxx model:Galaxy_S23 transport_id:2
```

Parse: split by lines, skip header, extract serial (first token), model (after `model:`).

### Progress Reporting for Large Transfers

- `adb pull/push` does NOT natively output progress percentage
- **Approach 1 (subprocess)**: Parse stderr — newer ADB versions show bytes transferred
- **Approach 2 (pre-scan)**: Run `adb shell du -sh` first to get total size, then track local file size during pull
- **Approach 3 (python-adb library)**: Use `adb_shell` or `python-adb` which expose `progress_callback(filename, bytes_written, total_bytes)` — this is the cleanest option
- **Recommended**: Use `adb_shell` library with `progress_callback` for native progress reporting

---

## 3. WhatsApp Restore Flow (Critical Path)

### The Exact Sequence (User MUST follow this)

1. **OLD phone**: WhatsApp must have a recent local backup (automatic nightly, or manual via Settings → Chats → Chat backup)
2. **NEW phone**: Install WhatsApp from Play Store
3. **NEW phone**: Open WhatsApp, verify phone number, **stop before restoring**
4. **Tool介入**: Copy database + media files to new phone via ADB
5. **NEW phone**: Force-close WhatsApp, reopen → restore prompt appears

### Critical Constraints

- The destination phone's WhatsApp **MUST** create the `Android/media/com.whatsapp/WhatsApp/` directory first (by opening the app once)
- If the folder doesn't exist, WhatsApp won't detect the backup
- The `Databases/` subfolder must be created manually (or by our tool via `adb shell mkdir`)
- Database file must be named `msgstore.db.crypt{14,15}` — rename if needed
- Google Drive backup must be disconnected on new phone if user wants local restore
- **Timing matters**: User must open WhatsApp on new phone, then our tool pushes files, then user reopens WhatsApp

### Restore Detection Logic (WhatsApp's behavior)

WhatsApp on the new phone looks for:
1. `/sdcard/Android/media/com.whatsapp/WhatsApp/Databases/msgstore.db.crypt15` (or crypt14)
2. If found → shows "Backup found" dialog
3. User taps "Restore" → WhatsApp decrypts and imports

---

## 4. Architecture Approach

### Option A: Flutter + gRPC + Python (via flutter_python_starter)

```
┌─────────────────────┐
│  Flutter Desktop UI  │  (Dart - wizard flow, progress bars)
│  Stepper/ Wizard     │
└──────────┬──────────┘
           │ gRPC (protobuf)
           ▼
┌─────────────────────┐
│  Python gRPC Server  │  (bundled via PyInstaller)
│  ADB operations      │
│  File management     │
└──────────┬──────────┘
           │ subprocess / python-adb
           ▼
┌─────────────────────┐
│  ADB (adb binary)    │  (or python-adb library)
│  USB Debug Bridge    │
└─────────────────────┘
```

**Pros**:
- Battle-tested pattern (flutter_python_starter kit exists)
- Clean separation of concerns
- Python has excellent ADB libraries
- gRPC provides type-safe contract (protobuf)
- Progress streaming via server-streaming RPC

**Cons**:
- Heavier setup (protoc, PyInstaller, gRPC deps)
- Two processes to manage (Flutter + Python server)
- Bundle size increases (~20-30MB for Python runtime)
- More complex debugging (two languages)

**Effort**: Medium-High

### Option B: Flutter + subprocess (no Python backend)

```
┌─────────────────────┐
│  Flutter Desktop UI  │  (Dart)
│  wizard_stepper      │
│  Process.run()       │  ← direct ADB calls
└──────────┬──────────┘
           │ Dart Process.run()
           ▼
┌─────────────────────┐
│  ADB binary          │  (must be installed by user or bundled)
└─────────────────────┘
```

**Pros**:
- No Python dependency
- Simpler architecture (single process)
- Easier to debug

**Cons**:
- Dart has no native ADB library — must shell out to `adb` binary
- Parsing ADB output in Dart is fragile
- Progress reporting requires manual parsing of ADB stderr
- User must have ADB installed and in PATH
- Less flexible for complex operations (file counting, size calculation)

**Effort**: Low-Medium

### Option C: Flutter + python-adb library (embedded Python via FFI)

```
┌─────────────────────┐
│  Flutter Desktop UI  │  (Dart)
│                      │
│  Dart FFI / Isolate  │  ← calls Python via C extension
└──────────┬──────────┘
           │ FFI
           ▼
┌─────────────────────┐
│  Python runtime      │  (embedded, not separate process)
│  python-adb library  │
└─────────────────────┘
```

**Pros**:
- Single process
- Direct Python ADB library access

**Cons**:
- Dart FFI with Python is extremely complex (CPython API)
- Not a well-trodden path
- Hard to bundle and distribute

**Effort**: High (not recommended)

### Recommended: Option A (gRPC + PyInstaller)

**Rationale**:
1. The `flutter_python_starter` kit provides production-ready scaffolding
2. Python's `adb-shell` library gives us native progress callbacks
3. gRPC streaming enables real-time progress updates to Flutter UI
4. PyInstaller bundles everything — user doesn't need Python installed
5. Clean testability: Python unit tests for ADB logic, Flutter tests for UI

---

## 5. Python Backend Design

### ADB Service (gRPC)

```protobuf
service AdbService {
  // Device discovery
  rpc ListDevices(ListDevicesRequest) returns (ListDevicesResponse);
  
  // Device info
  rpc GetDeviceInfo(GetDeviceInfoRequest) returns (DeviceInfo);
  
  // Transfer operations
  rpc PullWhatsAppData(PullRequest) returns (stream TransferProgress);
  rpc PushWhatsAppData(PushRequest) returns (stream TransferProgress);
  
  // File operations
  rpc GetFolderSize(GetFolderSizeRequest) returns (FolderSizeResponse);
  rpc CreateDirectory(CreateDirectoryRequest) returns (CreateDirectoryResponse);
}
```

### Key Python Classes

```
adb_service.py          ← gRPC service implementation
device_detector.py      ← List devices, detect WhatsApp
whatsapp_paths.py       ← Path resolution (Android version + package detection)
transfer_manager.py     ← Pull/Push with progress reporting
file_scanner.py         ← Scan source device for WhatsApp data
```

### Transfer Strategy

1. **Pre-scan phase**: List all files to transfer, calculate total size
2. **Pull phase**: Pull from OLD phone to temp directory on PC, with progress
3. **Push phase**: Push from temp directory to NEW phone, with progress
4. **Cleanup phase**: Remove temp files from PC
5. **Verification**: Compare file counts/sizes between source and destination

For 10GB+ transfers:
- Stream progress via gRPC server-streaming
- Show overall progress (bytes transferred / total bytes)
- Show current file being transferred
- Allow cancellation

---

## 6. Flutter UI Design

### Wizard Flow (5 steps)

```
Step 1: Welcome & Requirements
  → Check ADB installed, show requirements
  
Step 2: Connect Phones
  → Detect connected devices via ADB
  → User selects OLD (source) and NEW (destination)
  → Show device info (model, Android version, WhatsApp detected)
  
Step 3: Scan Source
  → Scan OLD phone for WhatsApp data
  → Show what will be transferred (database + media breakdown)
  → Calculate total size
  → User confirms what to transfer
  
Step 4: Transfer
  → Pull from OLD phone → PC temp dir → Push to NEW phone
  → Real-time progress bars
  → ETA calculation
  → Cancel button
  
Step 5: Complete
  → Show transfer summary
  → Guide user through WhatsApp restore steps on NEW phone
  → Step-by-step instructions with screenshots
```

### UI Components

- `wizard_stepper` package for step navigation
- Custom progress widgets for transfer visualization
- Device selection cards with model/icon
- File tree view showing what will be transferred

---

## 7. Risks

### High Risk

1. **WhatsApp version changes**: WhatsApp may change backup format or paths in future versions. Mitigation: version detection, configurable paths.

2. **Android permission changes**: Future Android versions may restrict ADB access to `Android/media/`. Mitigation: Monitor Android releases, test on latest.

3. **Restore timing**: User must follow exact sequence (install → open → close → transfer → reopen). If they skip steps, restore fails. Mitigation: Clear step-by-step guide in UI.

### Medium Risk

4. **Large file transfers**: USB 2.0 speeds make 10GB+ transfers slow (30+ minutes). Mitigation: Show ETA, allow selective transfer.

5. **ADB not installed**: Users may not have ADB/platform-tools. Mitigation: Bundle ADB binary or provide install instructions.

6. **USB debugging not enabled**: Users must enable USB debugging on both phones. Mitigation: Show instructions in Step 1.

7. **Multiple WhatsApp versions**: User may have WhatsApp + WhatsApp Business on same phone. Mitigation: Detect both, let user choose which to transfer.

### Low Risk

8. **File system differences**: Some Android OEMs have custom storage layouts. Mitigation: Detect paths dynamically via `adb shell ls`.

9. **Encryption key mismatch**: If user changes phone number, old backups won't restore. Mitigation: Warn user if phone numbers differ.

---

## 8. Testing Strategy

### Python Backend Tests

- `test_device_detector.py` — mock ADB output, test parsing
- `test_whatsapp_paths.py` — test path resolution for different Android versions
- `test_transfer_manager.py` — mock ADB, test pull/push/progress
- `test_file_scanner.py` — mock device filesystem, test scan

### Flutter UI Tests

- `test_wizard_flow.dart` — test step navigation
- `test_device_selection.dart` — test device selection UI
- `test_progress_display.dart` — test progress bar updates

### Integration Tests (manual)

- Test with real devices (Android 10, 11, 12, 13, 14)
- Test WhatsApp vs WhatsApp Business
- Test large transfers (5GB+, 10GB+)
- Test error cases (disconnected device, full storage)

---

## 9. Dependencies

### Python

```
grpcio>=1.60.0          ← gRPC framework
grpcio-tools>=1.60.0    ← protobuf code generation
protobuf>=4.25.0        ← protobuf runtime
adb-shell[usb]>=0.4.4  ← ADB library (USB support)
pyinstaller>=6.0        ← bundle as standalone binary
```

### Flutter (Dart)

```
grpc: ^3.2.0            ← gRPC client
protobuf: ^3.1.0        ← protobuf runtime
wizard_stepper: ^1.0.0  ← wizard UI
path: ^1.9.0            ← path manipulation
```

---

## 10. Effort Estimate

| Component | Effort | Notes |
|-----------|--------|-------|
| Python gRPC service | 3-4 days | ADB wrapper + gRPC + protobuf |
| Flutter wizard UI | 3-4 days | 5-step wizard + progress |
| Transfer logic | 2-3 days | Pull/push with progress streaming |
| Device detection | 1-2 days | ADB parsing + WhatsApp detection |
| PyInstaller bundling | 1 day | Package Python as standalone |
| Testing | 2-3 days | Unit tests + manual device testing |
| Documentation | 1 day | User guide + README |
| **Total** | **13-18 days** | Single developer |

---

## Recommendation

**Use Option A: Flutter + gRPC + Python backend** with the `flutter_python_starter` kit as the foundation.

The key architectural decisions:
1. **gRPC with server-streaming** for real-time progress updates
2. **`adb-shell` library** (not subprocess) for native progress callbacks
3. **PyInstaller** to bundle Python as standalone — no user installation needed
4. **`wizard_stepper`** package for the guided UI flow
5. **Pre-scan → Pull → Push** strategy with temp directory on PC

This gives us the best balance of:
- Clean architecture (separation of concerns)
- User experience (real-time progress, guided flow)
- Maintainability (protobuf contract, testable components)
- Distribution (single executable, no dependencies)

---

**Ready for Proposal**: Yes — the exploration is complete. The orchestrator should proceed with `sdd-propose` to define scope, approach, and rollback plan.
