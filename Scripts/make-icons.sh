#!/bin/bash
# Generates Resources/AppIcon.icns from Scripts/GenerateAppIcon.swift, which
# renders the same CmdV mark used for the menu bar icon at every size macOS
# needs for an app bundle icon.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$(mktemp -d)"
ICONSET="$WORK_DIR/AppIcon.iconset"
mkdir -p "$ICONSET"

echo "==> Rendering icon PNGs…"
xcrun --sdk macosx swiftc -target arm64-apple-macos26.0 \
    "$ROOT_DIR/Scripts/GenerateAppIcon.swift" -o "$WORK_DIR/generate"
"$WORK_DIR/generate" "$ICONSET"

echo "==> Packaging .icns…"
iconutil -c icns "$ICONSET" -o "$ROOT_DIR/Resources/AppIcon.icns"

rm -rf "$WORK_DIR"
echo "==> Done: Resources/AppIcon.icns"
