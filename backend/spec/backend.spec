# -*- mode: python ; coding: utf-8 -*-
#
# PyInstaller spec for WhatsApp Transfer Tool — Python Backend
#
# Build command (run from project root):
#   pyinstaller backend/spec/backend.spec
#
# Output: dist/whatsapp-backend (Linux ELF) or dist/whatsapp-backend.exe (Windows)

import platform
from pathlib import Path

block_cipher = None

# Project root — run pyinstaller from project root directory
PROJECT_ROOT = Path.cwd()

# Determine ADB binary paths per platform
is_windows = platform.system() == "Windows"

# Binaries to bundle (each entry is (source_path_in_project, dest_subdir_in_bundle))
adb_binaries = []
if is_windows:
    adb_binaries = [
        (str(PROJECT_ROOT / "backend/bin/windows/adb.exe"), "bin"),
        (str(PROJECT_ROOT / "backend/bin/windows/AdbWinApi.dll"), "bin"),
        (str(PROJECT_ROOT / "backend/bin/windows/AdbWinUsbApi.dll"), "bin"),
    ]
else:
    adb_binaries = [
        (str(PROJECT_ROOT / "backend/bin/linux/adb"), "bin"),
    ]

a = Analysis(
    [str(PROJECT_ROOT / "backend/main.py")],
    pathex=[str(PROJECT_ROOT)],
    binaries=adb_binaries,
    datas=[],
    hiddenimports=[
        "backend.protocol",
        "backend.models",
        "backend.adb_manager",
        "backend.device_service",
        "backend.scanner_service",
        "backend.temp_storage",
        "backend.progress_reporter",
        "backend.transfer_engine",
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        "tkinter",
        "PyQt5",
        "PyQt6",
        "PySide2",
        "PySide6",
    ],
    noarchive=False,
)

pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name="whatsapp-backend",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
