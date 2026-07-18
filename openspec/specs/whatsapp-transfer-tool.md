# WhatsApp Transfer Tool Specification

## Purpose

Specification for a Flutter Desktop + Python backend application that transfers WhatsApp/WhatsApp Business data (databases + media) from a source Android phone to a destination Android phone via USB ADB. Target: Android 10- (legacy paths) and Android 11+ (scoped storage). No root, no decryption, no iOS, USB-only for v1.

---

## Capability: device-detection

### Purpose

Detect Android devices connected via USB ADB, enumerate device properties (model, serial, Android API level), and detect WhatsApp/WhatsApp Business package presence.

### Requirements

#### Requirement: Device Enumeration

The system **SHALL** enumerate all devices connected via USB with ADB authorization granted.

- The system **SHALL** invoke `adb devices -l` and parse `model`, `device` (serial), `transport_id`.
- The system **SHALL** report only devices in `device` state (authorized), excluding `unauthorized` and `offline`.
- The system **SHALL** refresh the device list on demand and poll every 2 seconds while the wizard is on the detection step.

#### Requirement: Device Properties

The system **SHALL** retrieve Android version (API level) and model name for each authorized device.

- The system **SHALL** invoke `adb -s <serial> shell getprop ro.build.version.sdk` and parse the integer API level.
- The system **SHALL** invoke `adb -s <serial> shell getprop ro.product.model` for the marketing model name.
- The system **SHALL** classify devices as `legacy` (API ≤ 29 / Android 10-) or `scoped` (API ≥ 30 / Android 11+) for path resolution.

#### Requirement: WhatsApp Package Detection

The system **SHALL** detect installed WhatsApp variants on each device.

- The system **SHALL** invoke `adb -s <serial> shell pm list packages -f` and match package names:
  - `com.whatsapp` → WhatsApp
  - `com.whatsapp.w4b` → WhatsApp Business
- The system **SHALL** report for each device: list of detected packages with their APK paths.
- The system **SHALL** treat a device as a valid source/destination only if at least one WhatsApp variant is installed.

### Scenarios

#### Scenario: Single Authorized Device with WhatsApp

- GIVEN one Android device connected via USB with USB debugging authorized
- AND WhatsApp (`com.whatsapp`) installed
- WHEN the user opens the detection step
- THEN the system SHALL list the device with model, serial, API level, and detected package `com.whatsapp`

#### Scenario: Multiple Authorized Devices

- GIVEN two Android devices connected via USB, both authorized
- WHEN the user opens the detection step
- THEN the system SHALL list both devices with their respective properties and detected WhatsApp packages
- AND the user SHALL be able to select source and destination (must be different devices)

#### Scenario: Unauthorized Device

- GIVEN one Android device connected via USB with USB debugging NOT authorized
- WHEN the user opens the detection step
- THEN the system SHALL NOT list the device as selectable
- AND the UI SHALL show a hint: "Authorize USB debugging on the device"

#### Scenario: Device with No WhatsApp Installed

- GIVEN an authorized Android device with no WhatsApp or WhatsApp Business installed
- WHEN the user opens the detection step
- THEN the system SHALL list the device but mark it as "No WhatsApp detected — cannot be source or destination"
- AND the user SHALL NOT be able to select it as source or destination

#### Scenario: ADB Not in PATH (Bundled Fallback)

- GIVEN ADB is not in system PATH
- AND a bundled ADB binary exists alongside the Python backend
- WHEN the system enumerates devices
- THEN the system SHALL use the bundled ADB binary transparently
- AND device enumeration SHALL succeed identically to system ADB

---

## Capability: data-discovery

### Purpose

Scan a source device for WhatsApp/WhatsApp Business database files and media directories, reporting paths and sizes for both legacy (Android ≤10) and scoped storage (Android ≥11) paths.

### Requirements

#### Requirement: Legacy Path Discovery (Android ≤10)

The system **SHALL** scan legacy WhatsApp paths on devices with API ≤ 29.

- The system **SHALL** probe these paths via `adb shell ls -la`:
  - `/sdcard/WhatsApp/Databases/`
  - `/sdcard/WhatsApp/Media/`
  - `/sdcard/WhatsApp Business/Databases/`
  - `/sdcard/WhatsApp Business/Media/`
- The system **SHALL** list all `.db` / `.crypt*` files under Databases with file sizes (via `du -b`).
- The system **SHALL** list media subdirectories (Images, Video, Audio, Documents, Stickers) under Media with total sizes (via `du -sb`).

#### Requirement: Scoped Storage Path Discovery (Android ≥11)

The system **SHALL** scan scoped storage paths on devices with API ≥ 30.

- The system **SHALL** probe these paths via `adb shell ls -la`:
  - `/sdcard/Android/media/com.whatsapp/WhatsApp/Databases/`
  - `/sdcard/Android/media/com.whatsapp/WhatsApp/Media/`
  - `/sdcard/Android/media/com.whatsapp.w4b/WhatsApp Business/Databases/`
  - `/sdcard/Android/media/com.whatsapp.w4b/WhatsApp Business/Media/`
- The system **SHALL** fall back to probing `/sdcard/Android/data/<package>/files/` if media paths are not found (some OEMs).
- The system **SHALL** list databases and media with sizes identically to legacy paths.

#### Requirement: Size Calculation

The system **SHALL** report accurate byte sizes for all discovered items.

- For databases: `adb shell du -b <file>` → exact bytes.
- For media directories: `adb shell du -sb <dir>` → recursive byte total.
- The system **SHALL** report sizes in bytes; UI converts to human-readable units.

#### Requirement: Package-Aware Discovery

The system **SHALL** only scan paths for packages detected on the device.

- If only `com.whatsapp` is installed, **SHALL NOT** scan `com.whatsapp.w4b` paths.
- If both are installed, **SHALL** scan both and label results with package name.

#### Requirement: Empty State Handling

The system **SHALL** report empty results gracefully.

- If a Databases directory exists but contains no `.crypt*` files → report empty list with size 0.
- If a Media directory exists but has no subdirectories → report empty media list.
- If neither legacy nor scoped paths exist → report "No WhatsApp data found on this device".

### Scenarios

#### Scenario: Android 10 Device with WhatsApp Data

- GIVEN a source device with API 29 (Android 10)
- AND WhatsApp installed with 3 database files (msgstore.db.crypt14, msgstore-2024-01-01.1.db.crypt14, wa.db.crypt14) and media folders (Images: 2.1 GB, Videos: 850 MB)
- WHEN the user selects this device as source and proceeds to data discovery
- THEN the system SHALL list all 3 databases with exact byte sizes
- AND SHALL list media categories with byte totals
- AND SHALL label all items as "WhatsApp (com.whatsapp)"

#### Scenario: Android 13 Device with WhatsApp Business Only

- GIVEN a source device with API 33 (Android 13)
- AND only WhatsApp Business (`com.whatsapp.w4b`) installed
- WHEN data discovery runs
- THEN the system SHALL probe scoped paths for `com.whatsapp.w4b` only
- AND SHALL NOT probe `com.whatsapp` paths
- AND SHALL label results as "WhatsApp Business (com.whatsapp.w4b)"

#### Scenario: OEM Scoped Storage Variation

- GIVEN an Android 12 device (API 31) from a manufacturer that stores WhatsApp media under `/sdcard/Android/data/com.whatsapp/files/Media/`
- WHEN data discovery runs and standard scoped media path is empty
- THEN the system SHALL fall back to probing `/sdcard/Android/data/com.whatsapp/files/`
- AND SHALL report media found there if present

#### Scenario: No WhatsApp Data Found

- GIVEN a source device with WhatsApp installed but no chats/media (fresh install)
- WHEN data discovery runs
- THEN the system SHALL report "No WhatsApp data found on this device" with empty lists
- AND the UI SHALL allow the user to proceed (transfer will be empty) or go back

---

## Capability: transfer-orchestration

### Purpose

Orchestrate the end-to-end transfer: pull data from source device to a temporary directory on the host PC, then push to the destination device. Manage the transfer lifecycle (start, pause, cancel, retry, complete).

### Requirements

#### Requirement: Pull Phase

The system **SHALL** pull all selected data from the source device to a temporary directory on the host.

- The system **SHALL** create a unique temp directory per transfer: `<tempdir>/whatsapp-transfer-<uuid>/`
- The system **SHALL** mirror the source directory structure under `source/<package>/Databases/` and `source/<package>/Media/`.
- The system **SHALL** invoke `adb pull` for each database file and each media directory recursively.
- The system **SHALL** preserve file timestamps and permissions where ADB supports it.

#### Requirement: Push Phase

The system **SHALL** push the pulled data to the destination device.

- The system **SHALL** determine destination paths based on the destination device's API level (legacy vs scoped) and installed packages.
- For legacy (API ≤ 29): push to `/sdcard/WhatsApp/` or `/sdcard/WhatsApp Business/`.
- For scoped (API ≥ 30): push to `/sdcard/Android/media/<package>/WhatsApp/` or equivalent.
- The system **SHALL** create destination directories via `adb shell mkdir -p` before push.
- The system **SHALL** invoke `adb push` for each database file and media directory.

#### Requirement: Transfer Lifecycle Management

The system **SHALL** manage the full transfer lifecycle.

- **Start**: Validate source/destination selection, verify temp space, begin pull phase.
- **Pause**: On user pause, signal `adb pull/push` subprocess to stop (SIGINT), preserve partial temp data.
- **Resume**: On resume, continue from the last incomplete file/directory (v1: restart current file; v2: resume via byte offset).
- **Cancel**: On cancel, kill all `adb` subprocesses, delete the entire temp directory, report "Cancelled" to UI.
- **Complete**: On success, delete temp directory, report "Transfer complete" with summary (bytes transferred, duration, file counts).
- **Failure**: On any error, preserve temp directory for inspection, report error with context (phase, file, ADB error output), offer retry.

#### Requirement: Package Mapping

The system **SHALL** map source packages to destination packages.

- If source has `com.whatsapp` and destination has `com.whatsapp` → map 1:1.
- If source has `com.whatsapp.w4b` and destination has `com.whatsapp.w4b` → map 1:1.
- If source has both but destination has only one → transfer only the matching package; warn user about the other.
- If destination has neither package → error: "Destination device must have WhatsApp or WhatsApp Business installed".

#### Requirement: Idempotent Push

The system **SHALL** make push operations idempotent (safe to re-run).

- `adb push` overwrites existing files by default — acceptable for v1.
- WhatsApp on the destination phone merges databases on restore; duplicate media files are deduplicated by WhatsApp.
- Re-running a failed/cancelled push **SHALL NOT** corrupt destination data.

### Scenarios

#### Scenario: Full Transfer Success (5 GB Mixed Data)

- GIVEN source device (API 29) with WhatsApp: 3 databases (total 150 MB) + media (Images 2 GB, Videos 2.5 GB, Audio 350 MB)
- AND destination device (API 33) with WhatsApp installed
- AND host PC has 20 GB free in temp directory
- WHEN user starts transfer
- THEN system SHALL pull all databases and media to temp dir preserving structure
- AND SHALL push to destination scoped storage paths
- AND SHALL report completion with total bytes, file count, duration
- AND destination SHALL have all data in correct scoped paths

#### Scenario: Transfer Paused and Resumed

- GIVEN a transfer in progress (pull phase, 2 GB of 5 GB transferred)
- WHEN user clicks Pause
- THEN system SHALL send SIGINT to `adb pull` subprocess
- AND SHALL preserve partial temp files
- WHEN user clicks Resume
- THEN system SHALL restart `adb pull` for the current file/directory
- AND SHALL continue with remaining items

#### Scenario: Transfer Cancelled Mid-Push

- GIVEN a transfer in push phase (3 GB of 5 GB pushed)
- WHEN user clicks Cancel
- THEN system SHALL kill `adb push` subprocess
- AND SHALL delete the entire temp directory
- AND SHALL report "Transfer cancelled" to UI
- AND destination device SHALL have only partially pushed data (user informed: "Re-run transfer to complete")

#### Scenario: Destination Missing WhatsApp Package

- GIVEN source has WhatsApp + WhatsApp Business
- AND destination has only WhatsApp Business installed
- WHEN user attempts to start transfer
- THEN system SHALL allow transfer of WhatsApp Business data only
- AND SHALL warn: "WhatsApp (com.whatsapp) not installed on destination — its data will not be transferred"

#### Scenario: Insufficient Temp Space

- GIVEN source data totals 15 GB
- AND host PC temp directory has 10 GB free
- WHEN user attempts to start transfer
- THEN system SHALL reject start with error: "Insufficient temp space. Need 16.5 GB (110% of source), 10 GB available"
- AND SHALL NOT start any ADB operations

---

## Capability: transfer-progress

### Purpose

Provide real-time progress updates during `adb pull` and `adb push` operations by parsing ADB stderr output for byte counts and percentages.

### Requirements

#### Requirement: ADB Progress Parsing

The system **SHALL** parse ADB stderr for progress information.

- Modern ADB (`adb pull/push`) outputs to stderr lines like: `45% 12.3 MB/s 2.1GB/4.7GB 00:12`
- The system **SHALL** parse: percentage, current bytes, total bytes, transfer rate, ETA.
- The system **SHALL** emit progress events at least every 2 seconds or on every percentage change, whichever is more frequent.

#### Requirement: Fallback Progress (Pre-scan)

The system **SHALL** support a fallback progress mode for older ADB versions that don't emit progress.

- Before pull/push, the system **SHALL** pre-scan total bytes via `du -sb` on source paths.
- During transfer, the system **SHALL** track bytes by wrapping `adb pull/push` in a custom stream reader that counts bytes written to disk (pull) or read from disk (push).
- The system **SHALL** emit calculated percentage = bytes_so_far / total_bytes × 100.

#### Requirement: Progress Event Protocol

The system **SHALL** emit JSON progress events over stdout (Python → Flutter) in this format:

```json
{
  "type": "progress",
  "transferId": "uuid",
  "phase": "pull|push",
  "package": "com.whatsapp",
  "item": "Databases/msgstore.db.crypt14",
  "bytesTransferred": 123456789,
  "bytesTotal": 5000000000,
  "percentage": 24.7,
  "transferRateBps": 12300000,
  "etaSeconds": 320
}
```

- Events **SHALL** be newline-delimited JSON (NDJSON).
- The `transferId` **SHALL** be a UUID generated at transfer start.
- `phase` **SHALL** be `"pull"` or `"push"`.
- `package` identifies the WhatsApp package being transferred.
- `item` is the current file or directory relative path.

#### Requirement: Phase Transition Events

The system **SHALL** emit phase transition events:

```json
{ "type": "phase_change", "transferId": "uuid", "from": "pull", "to": "push" }
{ "type": "phase_change", "transferId": "uuid", "from": "push", "to": "complete" }
```

#### Requirement: Error Progress Events

On transfer error, the system **SHALL** emit a final progress event with error details:

```json
{
  "type": "progress",
  "transferId": "uuid",
  "phase": "push",
  "error": { "code": "ADB_PUSH_FAILED", "message": "adb: error: failed to copy '...' to '...': Permission denied", "item": "Media/Images/IMG_123.jpg" }
}
```

### Scenarios

#### Scenario: Modern ADB Progress Reporting

- GIVEN ADB 34+ that emits progress to stderr
- WHEN pulling a 2 GB media directory
- THEN the system SHALL parse stderr lines in real-time
- AND SHALL emit progress events every ~2 seconds with accurate percentage, rate, ETA

#### Scenario: Legacy ADB Fallback Progress

- GIVEN ADB 30 that does NOT emit progress to stderr
- WHEN pushing a 500 MB database file
- THEN the system SHALL pre-scan total size
- AND SHALL track bytes written via stream wrapper
- AND SHALL emit calculated progress events at least every 2 seconds

#### Scenario: Multi-Item Progress Aggregation

- GIVEN a transfer with 3 databases + 4 media directories
- WHEN transfer runs
- THEN progress events SHALL include `item` field identifying current file/directory
- AND `bytesTotal` SHALL reflect the total for the entire transfer (all items)
- AND `bytesTransferred` SHALL accumulate across items

#### Scenario: Phase Change Notification

- GIVEN pull phase completes successfully
- WHEN push phase begins
- THEN system SHALL emit `phase_change` event from "pull" to "push"
- AND UI SHALL update phase indicator without resetting progress bar

---

## Capability: temp-storage-management

### Purpose

Manage the temporary storage directory on the host PC: creation, free space validation, and guaranteed cleanup on success, failure, or cancellation.

### Requirements

#### Requirement: Temp Directory Creation

The system **SHALL** create a unique temporary directory for each transfer.

- Path: `tempfile.gettempdir() / "whatsapp-transfer-<uuid>/"`
- The system **SHALL** create subdirectories: `source/`, `source/<package>/Databases/`, `source/<package>/Media/`.
- The system **SHALL** ensure the directory is created before any `adb pull` begins.

#### Requirement: Pre-Transfer Space Check

The system **SHALL** verify sufficient free space before starting the pull phase.

- The system **SHALL** calculate `required_bytes = source_total_bytes * 1.1` (110% headroom).
- The system **SHALL** query free space via `shutil.disk_usage(tempdir).free`.
- If `free < required_bytes` → **SHALL** abort with error: "Insufficient temp space. Need X GB, Y GB available."
- The check **SHALL** run after data discovery (when source sizes are known) and before pull starts.

#### Requirement: Cleanup on Success

The system **SHALL** delete the entire temp directory after a successful push phase.

- Cleanup **SHALL** be recursive: `shutil.rmtree(temp_dir)`.
- Cleanup **SHALL** occur after the final progress event (`phase_change` to `complete`) is emitted.

#### Requirement: Cleanup on Failure

The system **SHALL** preserve the temp directory on transfer failure for debugging.

- On any error (ADB failure, IO error, permission denied), the system **SHALL NOT** auto-delete.
- The system **SHALL** emit an error event with `temp_dir_path` so the UI can offer "Open temp folder" or "Retry".
- The user **SHALL** be able to manually trigger cleanup from the UI.

#### Requirement: Cleanup on Cancel

The system **SHALL** delete the temp directory immediately on user cancellation.

- On cancel signal, the system **SHALL** kill ADB subprocesses, then `shutil.rmtree(temp_dir)`.
- Cleanup **SHALL** be best-effort; if it fails (e.g., file locked), log warning but continue.

#### Requirement: Orphan Cleanup on Startup

The system **SHALL** clean up orphaned temp directories from previous crashed runs on backend startup.

- On Python backend start, scan `tempfile.gettempdir()` for directories matching `whatsapp-transfer-*`.
- For each, check if a corresponding transfer process is still alive (PID file or lock file).
- If no live process → delete the orphan directory.
- Log count of cleaned orphans.

### Scenarios

#### Scenario: Sufficient Space — Transfer Completes

- GIVEN source data totals 8 GB
- AND host temp has 50 GB free
- WHEN transfer starts
- THEN space check passes (need 8.8 GB, have 50 GB)
- AND temp directory is created
- AND on successful completion, temp directory is deleted

#### Scenario: Insufficient Space — Transfer Blocked

- GIVEN source data totals 15 GB
- AND host temp has 10 GB free
- WHEN user clicks Start Transfer
- THEN system SHALL show error: "Insufficient temp space. Need 16.5 GB, 10 GB available."
- AND SHALL NOT create temp directory or start ADB

#### Scenario: Cancel During Pull — Temp Cleaned

- GIVEN transfer in pull phase, 3 GB in temp
- WHEN user clicks Cancel
- THEN system SHALL kill adb pull
- AND SHALL delete temp directory within 2 seconds
- AND SHALL report "Cancelled" to UI

#### Scenario: ADB Failure — Temp Preserved

- GIVEN push phase fails with "Permission denied" on destination
- WHEN error occurs
- THEN temp directory SHALL remain intact at `/tmp/whatsapp-transfer-<uuid>/`
- AND error event SHALL include `temp_dir_path`
- AND UI SHALL show "Transfer failed. Data saved in temp folder. Fix issue and retry."

#### Scenario: Backend Restart Cleans Orphans

- GIVEN a previous transfer crashed, leaving `/tmp/whatsapp-transfer-abc123/`
- AND no Python backend process is running
- WHEN Python backend starts
- THEN it SHALL detect and delete the orphan directory
- AND log: "Cleaned 1 orphaned temp directory"

---

## Capability: restore-guidance

### Purpose

Provide step-by-step user guidance for completing the WhatsApp restore on the destination phone after data transfer completes. The tool transfers data but cannot trigger the in-app restore (WhatsApp handles that on first launch).

### Requirements

#### Requirement: Step-by-Step Restore Instructions

The system **SHALL** display ordered, platform-specific restore instructions after transfer completes.

- **Step 1**: "On your new phone, open WhatsApp and verify your phone number."
- **Step 2**: "WhatsApp will detect the local backup. Tap 'Restore' when prompted."
- **Step 3**: "Wait for restore to complete. Do not skip."
- **Step 4**: "Open chats to verify messages and media appear."

#### Requirement: Package-Specific Guidance

The system **SHALL** tailor instructions based on which packages were transferred.

- If only `com.whatsapp` transferred → show WhatsApp restore steps.
- If only `com.whatsapp.w4b` transferred → show WhatsApp Business restore steps.
- If both transferred → show both sets of steps, clearly separated.

#### Requirement: Troubleshooting Guidance

The system **SHALL** include common troubleshooting steps.

- "If 'Restore' doesn't appear: Ensure you're using the same phone number. WhatsApp only restores backups for the registered number."
- "If media doesn't appear: Wait for media to download in background (WhatsApp downloads media lazily)."
- "If databases are crypt14/15 and restore fails: Update WhatsApp to latest version on Play Store."
- "If you see 'Backup not found': Verify the data was pushed to the correct path for your Android version (Settings → Storage → Files → Android/media/com.whatsapp)."

#### Requirement: Path Verification Helper

The system **SHALL** offer a "Verify on Device" action.

- When clicked, the system **SHALL** run `adb -s <dest_serial> shell ls -la <destination_path>` for each transferred package.
- The system **SHALL** display the output so the user can confirm files exist on the device before opening WhatsApp.

#### Requirement: Re-run Guidance

The system **SHALL** inform the user that re-running the transfer is safe.

- "You can run the transfer again anytime. WhatsApp merges databases and deduplicates media on restore."

### Scenarios

#### Scenario: Successful Transfer — Restore Guidance Shown

- GIVEN transfer completed successfully for WhatsApp (com.whatsapp) on Android 13 destination
- WHEN the "Done" step is shown
- THEN the UI SHALL display numbered restore steps for WhatsApp
- AND SHALL include a "Verify on Device" button
- AND SHALL include troubleshooting tips

#### Scenario: Dual Package Transfer — Both Guidance Sets Shown

- GIVEN transfer completed for both WhatsApp and WhatsApp Business
- WHEN the "Done" step is shown
- THEN the UI SHALL show two sections: "Restore WhatsApp" and "Restore WhatsApp Business"
- EACH with numbered steps and verify buttons

#### Scenario: User Clicks Verify — ADB Lists Files

- GIVEN user clicks "Verify on Device" for WhatsApp on destination
- WHEN verification runs
- THEN system SHALL execute `adb -s <serial> shell ls -la /sdcard/Android/media/com.whatsapp/WhatsApp/Databases/`
- AND SHALL display file list with sizes in the UI

#### Scenario: Restore Fails — User Re-runs Transfer

- GIVEN user followed steps but WhatsApp shows "Backup not found"
- WHEN user re-runs the transfer tool
- THEN system SHALL allow re-transfer (idempotent push)
- AND SHALL show guidance: "Re-running is safe. WhatsApp merges on restore."

---

## Capability: adb-management

### Purpose

Manage ADB binary availability: detect system ADB, fall back to bundled ADB, verify version compatibility, and handle PATH setup across Windows and Linux.

### Requirements

#### Requirement: System ADB Detection

The system **SHALL** detect ADB in system PATH on startup.

- The system **SHALL** check `shutil.which("adb")` (or `where adb` on Windows).
- If found, the system **SHALL** run `adb version` and parse the version string (e.g., "Android Debug Bridge version 1.0.41 Version 34.0.5-...").
- The system **SHALL** require ADB version ≥ 31 (supports `adb pull/push` progress output).

#### Requirement: Bundled ADB Fallback

The system **SHALL** bundle platform-specific ADB binaries with the Python backend.

- Windows: `adb.exe`, `AdbWinApi.dll`, `AdbWinUsbApi.dll` in `backend/bin/windows/`
- Linux: `adb` binary in `backend/bin/linux/`
- On startup, if system ADB not found or version < 31, the system **SHALL** use the bundled binary.
- The system **SHALL** set the binary directory in `PATH` for subprocess calls.

#### Requirement: ADB Server Management

The system **SHALL** manage the ADB server lifecycle.

- On backend start: `adb start-server` (using selected binary).
- The system **SHALL** verify server is running: `adb devices` returns without error.
- On backend shutdown: `adb kill-server` (optional; leave running for other tools is acceptable).

#### Requirement: ADB Version Reporting

The system **SHALL** report the active ADB binary path and version to the Flutter UI.

- On backend startup, emit an event: `{ "type": "adb_info", "path": "/path/to/adb", "version": "34.0.5", "source": "bundled|system" }`.
- The UI **SHALL** display this in the About/Diagnostics section.

#### Requirement: USB Driver Guidance (Windows)

The system **SHALL** detect missing USB drivers on Windows and guide the user.

- If `adb devices` shows no devices but `lsusb`/`Get-PnpDevice` shows an Android device in "ADB Interface" or "Composite ADB Interface" with a warning icon:
- The system **SHALL** emit an event: `{ "type": "driver_issue", "message": "Android device detected but ADB interface missing. Install OEM USB drivers or Google USB Driver." }`
- The UI **SHALL** show a link to the Google USB Driver download page.

### Scenarios

#### Scenario: System ADB Available and Compatible

- GIVEN Windows PC with ADB 34.0.5 in PATH
- WHEN Python backend starts
- THEN system ADB is selected
- AND `adb_info` event reports `source: "system"`, `version: "34.0.5"`

#### Scenario: No System ADB — Bundled Used

- GIVEN Linux machine with no ADB installed
- WHEN Python backend starts
- THEN bundled `backend/bin/linux/adb` is used
- AND `adb_info` event reports `source: "bundled"`

#### Scenario: System ADB Too Old — Bundled Preferred

- GIVEN Windows with ADB 29.0.1 in PATH (no progress support)
- WHEN Python backend starts
- THEN bundled ADB 34+ is selected instead
- AND `adb_info` event reports `source: "bundled"`

#### Scenario: Windows Driver Issue Detected

- GIVEN Windows PC, phone connected via USB, USB debugging authorized
- BUT `adb devices` shows empty list
- AND Device Manager shows "Android Device" with yellow warning
- WHEN backend starts
- THEN `driver_issue` event is emitted
- AND UI shows actionable driver installation guidance

---

## Capability: cross-platform-bundle

### Purpose

Define the bundling and distribution requirements for the Flutter Desktop app and Python backend across Windows and Linux.

### Requirements

#### Requirement: Python Backend Bundling (PyInstaller)

The system **SHALL** produce a single-file executable for the Python backend per platform.

- **Windows**: `whatsapp-backend.exe` via `pyinstaller --onefile --noconsole backend.spec`
  - Include bundled ADB binaries as `--add-binary` resources.
  - Set `--uac-admin` not required (ADB works without admin if drivers installed).
- **Linux**: `whatsapp-backend` (ELF binary) via `pyinstaller --onefile backend.spec`
  - Bundle ADB binary.
  - Set executable bit.
- The spec file **SHALL** include all Python dependencies: `psutil`, `pyyaml` (if used), stdlib only preferred.
- The binary **SHALL** accept JSON commands via stdin and emit JSON events via stdout.
- The binary **SHALL** set stdout/stderr to unbuffered mode (`-u` or `PYTHONUNBUFFERED=1`).

#### Requirement: Flutter Desktop Build

The system **SHALL** produce native Flutter Desktop binaries.

- **Windows**: `flutter build windows --release` → `build/windows/x64/runner/Release/whatsapp_transfer.exe`
  - Bundle Visual C++ Redistributable check (documented, not bundled).
- **Linux**: `flutter build linux --release` → `build/linux/x64/release/bundle/whatsapp_transfer`
  - Produce AppImage via `linuxdeploy` for distribution (v1: zip only, v2: AppImage).

#### Requirement: Backend Binary Embedding in Flutter App

The system **SHALL** embed the Python backend binary inside the Flutter app bundle.

- **Windows**: Copy `whatsapp-backend.exe` to `build/windows/x64/runner/Release/backend/`
- **Linux**: Copy `whatsapp-backend` to `build/linux/x64/release/bundle/backend/`
- Flutter app **SHALL** launch the backend as a child process (`Process.start`) with stdin/stdout pipes.
- The backend path **SHALL** be resolved relative to the Flutter executable at runtime.

#### Requirement: Communication Protocol

The system **SHALL** use JSON Lines (NDJSON) over stdin/stdout.

- **Flutter → Python (request)**:
  ```json
  {"type": "request", "id": "uuid", "method": "device.list", "params": {}}
  ```
- **Python → Flutter (response)**:
  ```json
  {"type": "response", "id": "uuid", "result": {"devices": [...]}}
  ```
- **Python → Flutter (progress/event)**:
  ```json
  {"type": "progress", "transferId": "uuid", ...}
  {"type": "event", "event": "adb_info", "data": {...}}
  ```
- **Error response**:
  ```json
  {"type": "response", "id": "uuid", "error": {"code": "DEVICE_NOT_FOUND", "message": "..."}}
  ```

#### Requirement: Installer Packaging (v1: Manual, v2: Installers)

- **v1 (MVP)**: Distribute as zip archives:
  - Windows: `whatsapp-transfer-windows.zip` containing `whatsapp_transfer.exe` + `backend/` folder.
  - Linux: `whatsapp-transfer-linux.tar.gz` containing `whatsapp_transfer` + `backend/` folder.
- **v2+**: NSIS installer (Windows), AppImage/Flatpak (Linux).

#### Requirement: Cross-Platform Path Handling

The system **SHALL** handle path differences correctly.

- Python backend **SHALL** use `pathlib.Path` for all filesystem operations.
- Temp directory: `tempfile.gettempdir()` (works on both).
- ADB binary paths: resolved relative to the backend binary location (`sys._MEIPASS` for PyInstaller).
- Flutter **SHALL** pass the backend binary path as an argument or resolve via `Platform.resolvedExecutable`.

### Scenarios

#### Scenario: Windows Build Produces Working Bundle

- GIVEN Flutter project on Windows with Python backend
- WHEN `flutter build windows --release` runs
- AND PyInstaller builds `whatsapp-backend.exe`
- AND backend is copied to `build/windows/.../Release/backend/`
- THEN running `whatsapp_transfer.exe` launches the Flutter UI
- AND clicking "Start" spawns the backend process
- AND device detection works via bundled ADB

#### Scenario: Linux Build Produces Working Bundle

- GIVEN Flutter project on Ubuntu 22.04 with Python backend
- WHEN `flutter build linux --release` runs
- AND PyInstaller builds `whatsapp-backend` ELF binary
- AND backend is copied to `build/linux/.../bundle/backend/`
- THEN running the binary launches the Flutter UI
- AND device detection works via bundled ADB

#### Scenario: Protocol Round-Trip Works

- GIVEN Flutter app and Python backend running
- WHEN Flutter sends `{"type":"request","id":"1","method":"device.list","params":{}}`
- THEN Python backend responds with `{"type":"response","id":"1","result":{"devices":[...]}}`
- AND no deadlock occurs on stdin/stdout pipes

#### Scenario: Progress Events Stream in Real-Time

- GIVEN a transfer in progress
- WHEN Python backend emits progress NDJSON lines
- THEN Flutter receives and parses each line within 100ms
- AND UI progress bar updates smoothly

---

## Cross-Cutting Requirements

### Non-Functional Requirements

#### NFR: Performance

- **Transfer throughput**: ≥ 80% of USB 3.0 theoretical max (≈ 400 MB/s) for large media files.
- **Progress latency**: ≤ 2 seconds between ADB progress output and UI update.
- **Startup time**: Flutter app cold start ≤ 3 seconds; Python backend spawn ≤ 1 second.

#### NFR: Reliability

- **Cancel safety**: Cancel at any point leaves no corrupted data on destination phone (partial data is acceptable; WhatsApp handles merge).
- **Crash recovery**: Backend crash preserves temp data; UI offers retry.
- **ADB disconnect resilience**: Detect disconnect within 5 seconds; pause transfer; prompt reconnect.

#### NFR: Usability

- **Wizard flow**: 4 steps max (Detect → Select Data → Transfer → Done).
- **Progress visibility**: Always show current phase, item, percentage, speed, ETA.
- **Error actionability**: Every error includes a user-actionable suggestion.

#### NFR: Compatibility

- **Windows**: 10 1909+ (1809+ with VC++ redist), x64 only for v1.
- **Linux**: Ubuntu 22.04+, Fedora 38+, Arch (glibc 2.35+), x64 only for v1.
- **Android**: API 21+ (Android 5.0) for ADB; API 29/30 split for paths.
- **WhatsApp**: Supports crypt12/14/15 databases (WhatsApp handles decrypt on restore).

#### NFR: Security

- **No data logging**: Python backend **SHALL NOT** log message content, phone numbers, or media filenames to disk.
- **Temp dir permissions**: Temp directory **SHALL** be created with `0o700` permissions (owner only).
- **ADB auth**: Tool **SHALL NOT** bypass ADB authorization; user must approve on phone.

---

## Acceptance Criteria Summary

| Capability | Acceptance Criteria |
|------------|---------------------|
| device-detection | Lists authorized USB devices with model, serial, API level, WhatsApp packages. Polls every 2s. Handles unauthorized devices gracefully. Bundled ADB fallback works. |
| data-discovery | Lists databases + media with byte sizes for legacy (≤API 29) and scoped (≥API 30) paths. Handles OEM path variations. Package-aware. Empty states handled. |
| transfer-orchestration | Pull → temp → push works for 5+ GB mixed data. Pause/resume/cancel functional. Idempotent push. Package mapping correct. Temp space pre-check enforced. |
| transfer-progress | Real-time progress events every ≤2s via NDJSON. Parses modern ADB stderr. Fallback pre-scan works. Phase change events emitted. |
| temp-storage-management | Unique temp dir per transfer. 110% space check. Cleanup on success/cancel. Preserve on failure. Orphan cleanup on backend start. |
| restore-guidance | Step-by-step restore instructions shown post-transfer. Package-specific. Verify-on-device action works. Troubleshooting tips included. Re-run guidance clear. |
| adb-management | System ADB detected, version checked. Bundled ADB fallback on missing/old. ADB server managed. Windows driver issues detected and guided. |
| cross-platform-bundle | PyInstaller --onefile works on Windows (.exe) and Linux (ELF). Flutter Desktop builds. Backend embedded and spawned correctly. NDJSON protocol works without deadlocks. |

---

## Open Questions for Design Phase

1. **Streaming pull→push (v2)**: Can we stream `adb pull` stdout directly to `adb push` stdin to avoid temp storage entirely? (Requires ADB support for stdin/stdout piping.)
2. **Incremental transfer (v2)**: Support resuming from last completed file using manifest file in temp dir.
3. **Linux distribution packaging**: AppImage vs Flatpak vs Snap — which to prioritize for v2?
4. **Windows ARM64**: Support for Windows on ARM (Snapdragon X Elite) — PyInstaller and Flutter both support it; add to v1 or v2?
5. **Multiple device selection**: UI for selecting source/dest when >2 devices connected — radio buttons or dropdown?