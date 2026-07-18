@echo off
REM download-adb.bat — Download Android platform-tools and extract adb for Windows
REM
REM Usage: download-adb.bat
REM
REM Downloads the latest Android platform-tools from Google's repository
REM and extracts adb.exe, AdbWinApi.dll, and AdbWinUsbApi.dll to this directory.
REM
REM Requires: curl (Windows 10/11 built-in or from chocolatey)

setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "PLATFORM_TOOLS_URL=https://dl.google.com/android/repository/platform-tools-latest-windows.zip"
set "TEMP_DIR=%TEMP%\whatsapp-adb-download"

if exist "%TEMP_DIR%" rmdir /s /q "%TEMP_DIR%"
mkdir "%TEMP_DIR%"

echo Downloading platform-tools from %PLATFORM_TOOLS_URL% ...
curl -fsSL "%PLATFORM_TOOLS_URL%" -o "%TEMP_DIR%\platform-tools.zip"
if %ERRORLEVEL% neq 0 (
    echo ERROR: Download failed. Check your internet connection.
    rmdir /s /q "%TEMP_DIR%"
    exit /b 1
)

echo Extracting adb binary...
powershell -command "Expand-Archive '%TEMP_DIR%\platform-tools.zip' -DestinationPath '%TEMP_DIR%\extracted'"
if %ERRORLEVEL% neq 0 (
    echo ERROR: Extraction failed.
    rmdir /s /q "%TEMP_DIR%"
    exit /b 1
)

copy /Y "%TEMP_DIR%\extracted\platform-tools\adb.exe" "%SCRIPT_DIR%adb.exe"
copy /Y "%TEMP_DIR%\extracted\platform-tools\AdbWinApi.dll" "%SCRIPT_DIR%AdbWinApi.dll"
copy /Y "%TEMP_DIR%\extracted\platform-tools\AdbWinUsbApi.dll" "%SCRIPT_DIR%AdbWinUsbApi.dll"

rmdir /s /q "%TEMP_DIR%"

echo Done! Files extracted to %SCRIPT_DIR%
echo.
echo Verify with: "%SCRIPT_DIR%adb.exe version"
