# Proposal: WhatsApp Transfer Tool

## Intent

Build a Flutter Desktop app (Windows + Linux) with Python backend that transfers WhatsApp and WhatsApp Business data (chats + media) from an old Android phone to a new one via ADB over USB — no cloud backup required. Target: Android 10- (legacy path) and Android 11+ (scoped storage). v1 is USB-only; no root, no decryption, no iOS.

## Scope

### In Scope
- Flutter Desktop wizard UI (4 steps: detect → select → transfer → done)
- Python backend using `subprocess` to invoke ADB (bundled via PyInstaller)
- JSON-over-stdin/stdout communication between Flutter and Python binary
- Detect connected Android devices, Android API level, WhatsApp / WhatsApp Business packages
- Detect data paths for Android 10- (legacy `/sdcard/WhatsApp/`) and Android 11+ (scoped storage `/sdcard/Android/media/com.whatsapp/`)
- Pre-scan source device: list databases + media folders with sizes
- Transfer flow: `adb pull` → temp dir on PC → `adb push` to destination
- Real-time progress reporting for `adb pull/push` (parse ADB stderr bytes)
- Support WhatsApp (`com.whatsapp`) and WhatsApp Business (`com.whatsapp.w4b`)
- Cross-platform: Windows + Linux (Flutter Desktop + PyInstaller binaries for each)
- USB-only ADB (no wireless ADB for v1)

### Out of Scope
- Decrypting WhatsApp crypt12/14/15 databases (WhatsApp on new phone handles restore)
- Viewing/reading WhatsApp messages inside the tool
- iOS / iPhone support
- Wireless ADB (TCP/IP)
- Rooted-device features (direct filesystem access, key extraction)
- Multi-device / multi-account parallel transfers
- Incremental/delta transfers (full pull/push for v1)

## Capabilities

### New Capabilities
- `device-detection`: ADB device enumeration, Android version, WhatsApp package detection
- `data-discovery`: Scan source device for WhatsApp/WhatsApp Business database files and media folders with sizes
- `transfer-orchestration`: Orchestrate pull → temp store → push with progress streaming
- `transfer-progress`: Real-time progress reporting from ADB stderr byte counts
- `temp-storage-management`: Temp directory creation, space check, cleanup on success/failure/abort
- `cross-platform-bundle`: PyInstaller bundling for Windows (`.exe`) + Linux (binary), Flutter Desktop build

### Modified Capabilities
- None (greenfield project)

## Approach

- **UI**: Flutter Desktop (Material 3) wizard with 4-step flow. Stepper with progress indicators.
- **Backend**: Python 3.14 + `subprocess` calling system ADB (bundled or PATH). JSON-over-stdin/stdout protocol between Flutter and Python binary.
- **Bundling**: PyInstaller `--onefile` per platform (Windows `.exe`, Linux ELF). Flutter `flutter build windows` / `flutter build linux` produces native binaries. Installer: NSIS (Windows) + AppImage/Flatpak (Linux) — out of scope for v1 MVP, manual zip for v1.
- **Protocol**: JSON lines over stdin/stdout. Messages: `{type: "request", id, method, params}`, `{type: "response", id, result|error}`, `{type: "progress", transferId, bytes, total}`.
- **ADB Strategy**: Bundle platform-specific ADB binary with Python binary (or rely on system ADB in PATH). Parse `adb devices -l`, `getprop`, `pm list packages`, `ls`, `du`, `pull`, `push`, `mkdir`.
- **Progress**: Parse `adb pull/push` stderr for byte counts (newer ADB outputs `XX% XX bytes/s`). Fallback: pre-scan sizes via `du -sh`, then track bytes via custom wrapper.
- **Temp Storage**: OS temp dir (`tempfile.gettempdir()`), check free space ≥ source size × 1.1 before pull. Cleanup on success/failure/cancel.
- **Testing**: Python `pytest` for backend logic (mock `subprocess`), Flutter `flutter_test` for UI, integration tests with `adb` against emulator.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `flutter_app/lib/` | New | Wizard UI, state machine, Python process manager |
| `python_backend/` | New | ADB wrapper, protocol server, transfer orchestrator |
| `build/` | New | PyInstaller specs, Flutter build configs, bundling scripts |
| `openspec/specs/` | New | Specs for each new capability (see Capabilities) |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| ADB not in PATH / version mismatch | High | Bundle platform-specific ADB binary with Python backend |
| Scoped storage path differences across OEMs | Medium | Probe both legacy + scoped paths; fallback to `ls /sdcard` |
| Large transfers (>10 GB) exhaust PC temp space | Medium | Pre-check free space; stream pull→push without full temp store (v2) |
| ADB auth dialog not accepted on phone | High | UI guides user to "Allow USB debugging" prompt; poll `adb devices` until `device` state |
| WhatsApp database format changes (crypt16+) | Low | We don't decrypt; WhatsApp on new phone handles restore |
| Linux desktop distribution fragmentation | Medium | Distribute AppImage/Flatpak; test on Ubuntu, Fedora, Arch |
| PyInstaller + subprocess + Flutter stdin/stdout deadlocks | Medium | Use async I/O, separate threads for stdout/stderr, timeouts |

## Rollback Plan

1. **User cancels during transfer**: Python backend receives cancel signal → kills `adb pull/push` subprocesses → deletes partial temp files → reports "Cancelled" to Flutter.
2. **Transfer fails mid-push**: Destination device may have partial data. User can re-run transfer (WhatsApp merge handles duplicates). Document "re-run is safe" in UI.
3. **Python backend crashes**: Flutter detects process exit → shows error → offers retry. No data modified on phones until push completes.
4. **ADB connection lost**: Detect via `adb devices` poll → pause transfer → prompt reconnect → resume from last completed file (v2) or restart (v1).
5. **Full uninstall**: Delete installed Flutter app + Python binary + temp dir. No system modifications.

## Dependencies

- **Flutter SDK** 3.44.1 (stable channel)
- **Python** 3.14
- **ADB** platform tools (bundled or system PATH)
- **PyInstaller** 6.x for bundling
- **NSIS** (Windows installer, v2+) / **AppImageTool** (Linux, v2+)

## Success Criteria

- [ ] Detects Android device + WhatsApp/WhatsApp Business on both source and destination
- [ ] Lists databases + media folders with correct sizes for Android 10- and 11+
- [ ] Transfers 5 GB test dataset (mixed DB + media) in < 15 min on USB 3.0
- [ ] Progress bar updates at least every 2 seconds during transfer
- [ ] Works on Windows 10/11 and Ubuntu 22.04+ / Fedora 38+
- [ ] Clean cancel leaves no partial data on destination phone
- [ ] Single executable per platform (Flutter app + bundled Python backend)

## Next Step

Proceed to `sdd-spec` to write delta specs for each new capability in `openspec/specs/`.