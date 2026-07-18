#!/usr/bin/env bash
# download-adb.sh — Download Android platform-tools and extract adb for Linux
#
# Usage: bash download-adb.sh
#
# Downloads the latest Android platform-tools from Google's repository
# and extracts only the adb binary to this directory.
#
# Requires: curl, unzip

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_DIR="$SCRIPT_DIR"

PLATFORM_TOOLS_URL="https://dl.google.com/android/repository/platform-tools-latest-linux.zip"
TEMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

echo "Downloading platform-tools from $PLATFORM_TOOLS_URL ..."
curl -fsSL "$PLATFORM_TOOLS_URL" -o "$TEMP_DIR/platform-tools.zip"

echo "Extracting adb binary..."
unzip -q "$TEMP_DIR/platform-tools.zip" -d "$TEMP_DIR/extracted"
cp "$TEMP_DIR/extracted/platform-tools/adb" "$DEST_DIR/adb"
chmod +x "$DEST_DIR/adb"

echo "Done! ADB binary extracted to $DEST_DIR/adb"
echo ""
echo "Verify with: $DEST_DIR/adb version"
