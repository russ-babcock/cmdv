#!/bin/bash
# Builds Resources/AppIcon.icns from the design source in CmdV-3A-Paper/.
#
# The art ships at 128/256/512/1024; macOS also wants 16/32/64, which are
# downscaled from the 1024 master here rather than being kept as more files to
# regenerate by hand. Replacing the icon means replacing the PNGs in
# CmdV-3A-Paper/app-icon/ and re-running this.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ART_DIR="$ROOT_DIR/CmdV-3A-Paper/app-icon"
WORK_DIR="$(mktemp -d)"
ICONSET="$WORK_DIR/AppIcon.iconset"
mkdir -p "$ICONSET"
trap 'rm -rf "$WORK_DIR"' EXIT

MASTER="$ART_DIR/CmdV-1024.png"
if [[ ! -f "$MASTER" ]]; then
    echo "error: $MASTER not found." >&2
    exit 1
fi

# name:size:source — the supplied sizes are used verbatim so the art is never
# resampled when an exact rendering already exists.
entries=(
    "icon_16x16.png:16:$MASTER"
    "icon_16x16@2x.png:32:$MASTER"
    "icon_32x32.png:32:$MASTER"
    "icon_32x32@2x.png:64:$MASTER"
    "icon_128x128.png:128:$ART_DIR/CmdV-128.png"
    "icon_128x128@2x.png:256:$ART_DIR/CmdV-256.png"
    "icon_256x256.png:256:$ART_DIR/CmdV-256.png"
    "icon_256x256@2x.png:512:$ART_DIR/CmdV-512.png"
    "icon_512x512.png:512:$ART_DIR/CmdV-512.png"
    "icon_512x512@2x.png:1024:$MASTER"
)

echo "==> Assembling iconset…"
for entry in "${entries[@]}"; do
    name="${entry%%:*}"
    rest="${entry#*:}"
    size="${rest%%:*}"
    source="${rest#*:}"

    actual="$(sips -g pixelWidth "$source" | awk '/pixelWidth/{print $2}')"
    if [[ "$actual" == "$size" ]]; then
        cp "$source" "$ICONSET/$name"
    else
        sips -z "$size" "$size" "$source" --out "$ICONSET/$name" > /dev/null
    fi
done

echo "==> Packaging .icns…"
iconutil -c icns "$ICONSET" -o "$ROOT_DIR/Resources/AppIcon.icns"

echo "==> Done: Resources/AppIcon.icns"
